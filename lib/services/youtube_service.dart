import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// Fetches video metadata and available stream options in one call.
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

    final info = VideoInfo.fromVideo(video);
    final videoStreams = _buildVideoOptions(manifest);
    final audioStreams = _buildAudioOptions(manifest);

    return (info: info, videoStreams: videoStreams, audioStreams: audioStreams);
  }

  /// Downloads [streamInfo] to a temp file and saves it to the gallery (video)
  /// or the app Documents folder (audio). Emits [DownloadProgress] events.
  Stream<DownloadProgress> download({
    required StreamInfo streamInfo,
    required String safeTitle,
    required bool isVideo,
    required void Function(DownloadResult) onComplete,
    required void Function(String) onError,
  }) async* {
    try {
      // ── Request permissions ────────────────────────────────────────────────
      if (isVideo) {
        final status = await Permission.photos.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          onError(
              'Photo Library permission is required to save videos. Please enable it in Settings.');
          return;
        }
      }

      // ── Prepare temp file ─────────────────────────────────────────────────
      final ext = isVideo ? 'mp4' : 'mp3';
      final tempDir = await getTemporaryDirectory();
      final sanitised = safeTitle
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, safeTitle.length.clamp(0, 50));
      final filePath = '${tempDir.path}/${sanitised}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File(filePath);
      final sink = file.openWrite();

      // ── Stream download ────────────────────────────────────────────────────
      final totalBytes = streamInfo.size.totalBytes;
      int downloadedBytes = 0;
      final stopwatch = Stopwatch()..start();
      int lastBytes = 0;
      int lastMs = 0;

      final dataStream = _yt.videos.streamsClient.get(streamInfo);

      await for (final chunk in dataStream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final nowMs = stopwatch.elapsedMilliseconds;
        final elapsedSinceLast = nowMs - lastMs;

        // Update speed every 300 ms to avoid jitter
        double speedMBps = 0;
        if (elapsedSinceLast >= 300) {
          final bytesSinceLast = downloadedBytes - lastBytes;
          speedMBps = bytesSinceLast / (elapsedSinceLast / 1000) / (1024 * 1024);
          lastBytes = downloadedBytes;
          lastMs = nowMs;
        }

        final progress =
            totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

        yield DownloadProgress(
          progress: progress,
          speedMBps: speedMBps,
        );
      }

      await sink.flush();
      await sink.close();

      // ── Save to destination ────────────────────────────────────────────────
      if (isVideo) {
        final result = await PhotoManager.editor.saveVideo(
          file,
          title: '$sanitised.$ext',
        );
        if (result == null) {
          onError('Failed to save video to photo library.');
          return;
        }
        onComplete(DownloadResult(filePath: filePath, savedToGallery: true));
      } else {
        // Save audio to the app's Documents directory
        final docsDir = await getApplicationDocumentsDirectory();
        final destPath = '${docsDir.path}/$sanitised.$ext';
        await file.copy(destPath);
        await file.delete(); // clean up temp
        onComplete(DownloadResult(filePath: destPath, savedToGallery: false));
      }
    } on YoutubeExplodeException catch (e) {
      onError('YouTube error: ${e.message}');
    } on SocketException {
      onError('No internet connection. Please check your network and try again.');
    } catch (e) {
      onError('Something went wrong: $e');
    }
  }

  void dispose() => _yt.close();

  // ─── Private helpers ────────────────────────────────────────────────────────

  String? _extractVideoId(String url) {
    // Accept bare video IDs too (11 chars, alphanumeric + - _)
    if (RegExp(r'^[\w\-]{11}$').hasMatch(url)) return url;

    try {
      final videoId = VideoId(url);
      return videoId.value;
    } catch (_) {
      return null;
    }
  }

  List<StreamOption> _buildVideoOptions(StreamManifest manifest) {
    final muxed = manifest.muxed
        .where((s) => s.container == StreamContainer.mp4)
        .toList()
      ..sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));

    // Deduplicate by quality label
    final seen = <String>{};
    return muxed
        .where((s) => seen.add(s.qualityLabel))
        .map((s) => StreamOption(label: s.qualityLabel, streamInfo: s))
        .toList();
  }

  List<StreamOption> _buildAudioOptions(StreamManifest manifest) {
    final audio = manifest.audioOnly
        .where((s) => s.container == StreamContainer.mp4) // AAC – good for iOS
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    final seen = <int>{};
    return audio.where((s) {
      final kbps = s.bitrate.kiloBitsPerSecond.round();
      return seen.add(kbps);
    }).map((s) {
      final kbps = s.bitrate.kiloBitsPerSecond.round();
      return StreamOption(label: '$kbps kbps', streamInfo: s);
    }).toList();
  }
}
