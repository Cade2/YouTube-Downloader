import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_info.dart';

/// Download progress event emitted during a stream download.
class DownloadProgress {
  /// 0.0 – 1.0
  final double progress;

  /// Current download speed in MB/s
  final double speedMBps;

  const DownloadProgress({required this.progress, required this.speedMBps});
}

/// Result returned after a successful download.
class DownloadResult {
  final String filePath;
  final bool savedToGallery;

  const DownloadResult({required this.filePath, required this.savedToGallery});
}

class YouTubeService {
  YouTubeService._();

  static final YouTubeService instance = YouTubeService._();

  final _yt = YoutubeExplode();

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Fetches video metadata and ALL available stream options.
  Future<
      ({
        VideoInfo info,
        List<StreamOption> videoStreams,
        List<StreamOption> audioStreams,
      })> fetchVideoData(String rawUrl) async {
    final videoId = _extractVideoId(rawUrl.trim());
    if (videoId == null) {
      throw const FormatException(
          'Could not find a valid YouTube URL. Please check and try again.');
    }

    final video = await _yt.videos.get(videoId);
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    // ── Debug: log every stream YouTube returned ───────────────────────────
    _logManifest(manifest);

    final info = VideoInfo.fromVideo(video);
    final videoStreams = _buildVideoOptions(manifest);
    final audioStreams = _buildAudioOptions(manifest);

    debugPrint('[PullTube] ─── Final video options (${videoStreams.length}) ───');
    for (final o in videoStreams) {
      debugPrint('[PullTube]   ${o.label}');
    }
    debugPrint('[PullTube] ─── Final audio options (${audioStreams.length}) ───');
    for (final o in audioStreams) {
      debugPrint('[PullTube]   ${o.label}');
    }

    return (info: info, videoStreams: videoStreams, audioStreams: audioStreams);
  }

  /// Downloads [streamInfo] and saves to gallery (MP4) or Documents (WebM/MP3).
  /// Yields [DownloadProgress] during the transfer.
  Stream<DownloadProgress> download({
    required StreamInfo streamInfo,
    required String safeTitle,
    required bool isVideo,
    required void Function(DownloadResult) onComplete,
    required void Function(String) onError,
  }) async* {
    try {
      // ── Determine output file extension from the stream's container ────────
      final ext = _resolveExtension(streamInfo, isVideo);
      final willSaveToGallery = isVideo && ext != 'webm';

      // ── Request photo library permission (for gallery-bound files) ─────────
      if (willSaveToGallery) {
        final ps = await PhotoManager.requestPermissionExtend();
        debugPrint('[PullTube] Photo permission state: $ps');
        if (ps == PermissionState.denied || ps == PermissionState.restricted) {
          onError(
              'Photo Library permission is required to save videos.\n'
              'Please enable it in Settings → Privacy → Photos.');
          return;
        }
      }

      // ── Prepare temp output file ───────────────────────────────────────────
      final tempDir = await getTemporaryDirectory();
      final sanitised = _sanitiseTitle(safeTitle);
      final filePath =
          '${tempDir.path}/${sanitised}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File(filePath);
      final sink = file.openWrite();

      debugPrint('[PullTube] Downloading → $filePath');
      debugPrint('[PullTube] Stream: ${streamInfo.size.totalMegaBytes.toStringAsFixed(1)} MB'
          ' | container: ${streamInfo.container.value}');

      // ── Pipe the YouTube stream to disk ────────────────────────────────────
      final totalBytes = streamInfo.size.totalBytes;
      int downloadedBytes = 0;
      int lastBytes = 0;
      int lastMs = 0;
      final stopwatch = Stopwatch()..start();

      await for (final chunk in _yt.videos.streamsClient.get(streamInfo)) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final nowMs = stopwatch.elapsedMilliseconds;
        final elapsedSinceLast = nowMs - lastMs;
        double speedMBps = 0;

        if (elapsedSinceLast >= 300) {
          final bytesDelta = downloadedBytes - lastBytes;
          speedMBps =
              bytesDelta / (elapsedSinceLast / 1000) / (1024 * 1024);
          lastBytes = downloadedBytes;
          lastMs = nowMs;
        }

        yield DownloadProgress(
          progress: totalBytes > 0
              ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0,
          speedMBps: speedMBps,
        );
      }

      await sink.flush();
      await sink.close();

      debugPrint('[PullTube] Download complete. Saving…');

      // ── Save to final destination ──────────────────────────────────────────
      if (willSaveToGallery) {
        // Save MP4 to the iOS Photos library (Camera Roll)
        final asset = await PhotoManager.editor.saveVideo(
          file,
          title: '$sanitised.$ext',
        );
        await file.delete(); // clean up temp copy
        if (asset == null) {
          onError(
              'The video downloaded successfully but could not be saved to the '
              'Photo Library. Check permissions in Settings → Privacy → Photos.');
          return;
        }
        debugPrint('[PullTube] Saved to gallery: ${asset.id}');
        onComplete(DownloadResult(filePath: filePath, savedToGallery: true));
      } else {
        // WebM video or audio → save to app Documents (accessible via Files app)
        final docsDir = await getApplicationDocumentsDirectory();
        final destPath = '${docsDir.path}/$sanitised.$ext';
        await file.copy(destPath);
        await file.delete();
        debugPrint('[PullTube] Saved to Documents: $destPath');
        onComplete(DownloadResult(filePath: destPath, savedToGallery: false));
      }
    } on YoutubeExplodeException catch (e) {
      debugPrint('[PullTube] YoutubeExplodeException: ${e.message}');
      onError('YouTube error: ${e.message}');
    } on SocketException {
      onError(
          'No internet connection. Please check your network and try again.');
    } catch (e, st) {
      debugPrint('[PullTube] Unexpected error: $e\n$st');
      onError('Something went wrong: $e');
    }
  }

  void dispose() => _yt.close();

  // ─── Private helpers ────────────────────────────────────────────────────────

  String? _extractVideoId(String url) {
    if (RegExp(r'^[\w\-]{11}$').hasMatch(url)) return url;
    try {
      return VideoId(url).value;
    } catch (_) {
      return null;
    }
  }

  /// Builds the MP4/video quality list from ALL available streams.
  ///
  /// YouTube serves streams in three groups:
  ///   - muxed       : video + audio combined, capped at ~720p, available in
  ///                   both MP4 and WebM containers.
  ///   - videoOnly   : video only, up to 4K, available in MP4 (H.264) and
  ///                   WebM (VP9 / AV1) — **no container filter applied here**
  ///                   because many videos only have 1080p+ as WebM.
  ///
  /// Strategy: build a map keyed by pixel height.
  ///   1. Add every videoOnly stream (prefer MP4 over WebM if both exist at
  ///      the same height).
  ///   2. Overwrite with muxed entries at the same height — muxed wins because
  ///      it includes audio.
  List<StreamOption> _buildVideoOptions(StreamManifest manifest) {
    // height → (streamInfo, label)
    final byHeight = <int, StreamOption>{};

    // ── Pass 1: all video-only streams, NO container filter ────────────────
    for (final s in manifest.videoOnly) {
      final h = s.videoResolution.height;
      final existing = byHeight[h];

      if (existing == null) {
        byHeight[h] = StreamOption(
          label: '${s.qualityLabel} (video only)',
          streamInfo: s,
        );
      } else {
        // At the same height, upgrade from WebM → MP4 if MP4 is available,
        // because MP4/H.264 is natively supported by the iOS Photos library.
        final existingIsWebM =
            existing.streamInfo.container == StreamContainer.webM;
        final newIsMp4 = s.container == StreamContainer.mp4;
        if (existingIsWebM && newIsMp4) {
          byHeight[h] = StreamOption(
            label: '${s.qualityLabel} (video only)',
            streamInfo: s,
          );
        }
      }
    }

    // ── Pass 2: muxed streams (audio+video) overwrite video-only ──────────
    for (final s in manifest.muxed) {
      // Accept all containers — prefer MP4 if both MP4 and WebM muxed exist
      final h = s.videoResolution.height;
      final existing = byHeight[h];
      if (existing == null) {
        byHeight[h] = StreamOption(label: s.qualityLabel, streamInfo: s);
      } else {
        // If current entry at this height is video-only, always replace with muxed
        final currentIsMuxed = existing.streamInfo is MuxedStreamInfo;
        if (!currentIsMuxed) {
          byHeight[h] = StreamOption(label: s.qualityLabel, streamInfo: s);
        } else {
          // Both muxed: prefer MP4 over WebM
          final existingIsWebM =
              existing.streamInfo.container == StreamContainer.webM;
          if (existingIsWebM && s.container == StreamContainer.mp4) {
            byHeight[h] = StreamOption(label: s.qualityLabel, streamInfo: s);
          }
        }
      }
    }

    final sorted = byHeight.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted.map((e) => e.value).toList();
  }

  /// Builds the audio (MP3) quality list from audioOnly streams.
  /// Accepts both MP4/AAC and WebM/Opus — prefers MP4/AAC for iOS compat.
  List<StreamOption> _buildAudioOptions(StreamManifest manifest) {
    // kbps → best stream at that bitrate
    final byKbps = <int, AudioOnlyStreamInfo>{};

    for (final s in manifest.audioOnly) {
      final kbps = s.bitrate.kiloBitsPerSecond.round();
      final existing = byKbps[kbps];
      if (existing == null) {
        byKbps[kbps] = s;
      } else {
        // Prefer MP4/AAC over WebM/Opus for better iOS compatibility
        if (existing.container != StreamContainer.mp4 &&
            s.container == StreamContainer.mp4) {
          byKbps[kbps] = s;
        }
      }
    }

    final sorted = byKbps.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted.map((e) {
      return StreamOption(label: '${e.key} kbps', streamInfo: e.value);
    }).toList();
  }

  /// Returns the correct file extension for the given stream.
  String _resolveExtension(StreamInfo info, bool isVideo) {
    if (!isVideo) return 'mp3';
    return info.container == StreamContainer.webM ? 'webm' : 'mp4';
  }

  String _sanitiseTitle(String title) {
    final clean = title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final clamped = clean.length > 50 ? clean.substring(0, 50) : clean;
    return clamped.isEmpty ? 'download' : clamped;
  }

  void _logManifest(StreamManifest manifest) {
    if (!kDebugMode) return;
    dev.log(
      '=== YouTube Stream Manifest ===\n'
      'Muxed (${manifest.muxed.length}):\n'
      '${manifest.muxed.map((s) => '  ${s.qualityLabel.padRight(8)} | ${s.container.value.padRight(5)} | ${s.size.totalMegaBytes.toStringAsFixed(1)} MB').join('\n')}\n'
      'VideoOnly (${manifest.videoOnly.length}):\n'
      '${manifest.videoOnly.map((s) => '  ${s.qualityLabel.padRight(8)} | ${s.container.value.padRight(5)} | ${s.videoResolution}').join('\n')}\n'
      'AudioOnly (${manifest.audioOnly.length}):\n'
      '${manifest.audioOnly.map((s) => '  ${s.bitrate.kiloBitsPerSecond.round().toString().padRight(6)} kbps | ${s.container.value}').join('\n')}',
      name: 'PullTube',
    );
  }
}
