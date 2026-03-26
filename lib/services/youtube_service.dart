import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_info.dart';

class FetchVideoResult {
  const FetchVideoResult({
    required this.videoInfo,
    required this.videoOptions,
    required this.audioOptions,
  });

  final VideoInfo videoInfo;
  final List<StreamOption> videoOptions;
  final List<StreamOption> audioOptions;
}

class DownloadProgress {
  const DownloadProgress({
    required this.progress,
    required this.speedInMegabytes,
    required this.receivedBytes,
    required this.totalBytes,
  });

  const DownloadProgress.zero()
    : progress = 0,
      speedInMegabytes = 0,
      receivedBytes = 0,
      totalBytes = 0;

  final double progress;
  final double speedInMegabytes;
  final int receivedBytes;
  final int totalBytes;

  String get percentLabel =>
      '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';

  String get transferredLabel {
    final received = _toMegabytes(receivedBytes);
    final total = totalBytes > 0 ? _toMegabytes(totalBytes) : null;
    if (total == null) {
      return '${received.toStringAsFixed(1)} MB';
    }
    return '${received.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} MB';
  }

  static double _toMegabytes(int bytes) => bytes / (1024 * 1024);
}

class DownloadResult {
  const DownloadResult({required this.savedToGallery, this.filePath});

  final bool savedToGallery;
  final String? filePath;
}

class YouTubeServiceException implements Exception {
  const YouTubeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class YouTubeService {
  YouTubeService()
    : _youtube = YoutubeExplode(),
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 15),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

  final YoutubeExplode _youtube;
  final Dio _dio;

  Future<FetchVideoResult> fetchVideoInfo(String rawUrl) async {
    final normalizedInput = rawUrl.trim();
    final videoId = _parseVideoId(normalizedInput);

    if (videoId == null) {
      throw const YouTubeServiceException(
        'Enter a valid YouTube link before fetching.',
      );
    }

    try {
      final video = await _youtube.videos.get(videoId);
      final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
      final videoInfo = VideoInfo.fromVideo(video);

      _logVideoHeader(videoInfo);
      _logMuxedStreams(manifest.muxed);
      _logVideoOnlyStreams(manifest.videoOnly);
      _logAudioOnlyStreams(manifest.audioOnly);

      final videoOptions = _buildVideoOptions(manifest);
      final audioOptions = _buildAudioOptions(manifest);

      _logFinalOptions(videoOptions: videoOptions, audioOptions: audioOptions);

      return FetchVideoResult(
        videoInfo: videoInfo,
        videoOptions: videoOptions,
        audioOptions: audioOptions,
      );
    } on YoutubeExplodeException catch (error) {
      throw YouTubeServiceException(_mapFetchException(error));
    } on SocketException {
      throw const YouTubeServiceException(
        'Network connection failed while contacting YouTube.',
      );
    } on HandshakeException {
      throw const YouTubeServiceException(
        'A secure connection to YouTube could not be established.',
      );
    } catch (error) {
      throw YouTubeServiceException(
        'Unable to fetch video details right now: $error',
      );
    }
  }

  Future<DownloadResult> downloadSelection({
    required VideoInfo videoInfo,
    required StreamOption option,
    required MediaFormat format,
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    File? temporaryFile;

    try {
      if (format == MediaFormat.mp4) {
        await _ensurePhotoLibraryPermission();
      }

      final temporaryDirectory = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(videoInfo.title);
      final fileName =
          '${safeName}_${DateTime.now().millisecondsSinceEpoch}.${option.fileExtension}';
      temporaryFile = File('${temporaryDirectory.path}/$fileName');

      final speedTracker = _SpeedTracker();
      final fallbackTotal = option.streamInfo.size.totalBytes;

      await _dio.downloadUri(
        Uri.parse(option.streamInfo.url.toString()),
        temporaryFile.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final expectedTotal = total > 0 ? total : fallbackTotal;
          final progress = expectedTotal > 0 ? received / expectedTotal : 0.0;

          onProgress(
            DownloadProgress(
              progress: progress.clamp(0, 1),
              speedInMegabytes: speedTracker.sample(received),
              receivedBytes: received,
              totalBytes: expectedTotal,
            ),
          );
        },
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      onProgress(
        DownloadProgress(
          progress: 1,
          speedInMegabytes: speedTracker.lastSpeed,
          receivedBytes: option.streamInfo.size.totalBytes,
          totalBytes: option.streamInfo.size.totalBytes,
        ),
      );

      if (format == MediaFormat.mp4) {
        await PhotoManager.editor.saveVideo(temporaryFile, title: fileName);

        await temporaryFile.delete();
        return const DownloadResult(savedToGallery: true);
      }

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final savedFile = File('${documentsDirectory.path}/$fileName');

      if (await savedFile.exists()) {
        await savedFile.delete();
      }

      final persistedFile = await temporaryFile.copy(savedFile.path);
      await temporaryFile.delete();

      return DownloadResult(
        savedToGallery: false,
        filePath: persistedFile.path,
      );
    } on DioException catch (error) {
      throw YouTubeServiceException(_mapDioException(error));
    } on YouTubeServiceException {
      rethrow;
    } on FileSystemException catch (error) {
      throw YouTubeServiceException('File saving failed: ${error.message}');
    } catch (error) {
      throw YouTubeServiceException('Download failed unexpectedly: $error');
    } finally {
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<void> _ensurePhotoLibraryPermission() async {
    if (!Platform.isIOS) {
      return;
    }

    final addOnlyStatus = await Permission.photosAddOnly.request();
    final hasPermission = addOnlyStatus.isGranted || addOnlyStatus.isLimited;

    if (!hasPermission) {
      final photosStatus = await Permission.photos.request();
      final isGranted = photosStatus.isGranted || photosStatus.isLimited;
      if (!isGranted) {
        throw const YouTubeServiceException(
          'Photo Library permission was denied. Allow access before saving video.',
        );
      }
    }

    final photoManagerState = await PhotoManager.requestPermissionExtend();
    final isAuthorized =
        photoManagerState == PermissionState.authorized ||
        photoManagerState == PermissionState.limited;

    if (!isAuthorized) {
      throw const YouTubeServiceException(
        'Photo Library access is still unavailable for gallery saving.',
      );
    }
  }

  List<StreamOption> _buildVideoOptions(StreamManifest manifest) {
    final optionsByHeight = <int, StreamOption>{};

    for (final stream in manifest.videoOnly) {
      final height = stream.videoResolution.height;
      final candidate = StreamOption(
        label: '${height}p',
        detail: '${stream.container.name.toUpperCase()}  -  Video only',
        streamInfo: stream,
        sortValue: height,
        container: stream.container.name,
        fileExtension: stream.container.name,
        hasAudio: false,
        isMuxed: false,
      );

      final current = optionsByHeight[height];
      if (current == null ||
          (current.container != 'mp4' && candidate.container == 'mp4')) {
        optionsByHeight[height] = candidate;
      }
    }

    for (final stream in manifest.muxed) {
      final height = stream.videoResolution.height;
      final candidate = StreamOption(
        label: '${height}p',
        detail: '${stream.container.name.toUpperCase()}  -  Audio included',
        streamInfo: stream,
        sortValue: height,
        container: stream.container.name,
        fileExtension: stream.container.name,
        hasAudio: true,
        isMuxed: true,
      );

      final current = optionsByHeight[height];
      if (current == null ||
          !current.isMuxed ||
          (current.container != 'mp4' && candidate.container == 'mp4')) {
        optionsByHeight[height] = candidate;
      }
    }

    final options = optionsByHeight.values.toList()
      ..sort((left, right) => right.sortValue.compareTo(left.sortValue));

    return options;
  }

  List<StreamOption> _buildAudioOptions(StreamManifest manifest) {
    final optionsByBitrate = <int, StreamOption>{};

    for (final stream in manifest.audioOnly) {
      final bitrate = stream.bitrate.kiloBitsPerSecond.round();
      final fileExtension = stream.container.name == 'mp4'
          ? 'm4a'
          : stream.container.name;
      final candidate = StreamOption(
        label: '$bitrate kbps',
        detail: '${stream.container.name.toUpperCase()}  -  Audio only',
        streamInfo: stream,
        sortValue: bitrate,
        container: stream.container.name,
        fileExtension: fileExtension,
        hasAudio: true,
        isMuxed: false,
      );

      final current = optionsByBitrate[bitrate];
      if (current == null ||
          (current.container != 'mp4' && candidate.container == 'mp4')) {
        optionsByBitrate[bitrate] = candidate;
      }
    }

    final options = optionsByBitrate.values.toList()
      ..sort((left, right) => right.sortValue.compareTo(left.sortValue));

    return options;
  }

  String? _parseVideoId(String input) {
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(input)) {
      return input;
    }

    try {
      return VideoId(input).value;
    } catch (_) {
      return null;
    }
  }

  String _mapFetchException(YoutubeExplodeException error) {
    final message = error.message.toLowerCase();

    if (message.contains('unavailable') ||
        message.contains('not available') ||
        message.contains('private')) {
      return 'This video is unavailable, private, or restricted.';
    }

    if (message.contains('playability') || message.contains('age')) {
      return 'This video appears to be restricted and cannot be downloaded.';
    }

    return 'YouTube rejected the request: ${error.message}';
  }

  String _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The download timed out before the stream finished.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'The stream download could not connect to YouTube.';
    }

    if (error.response?.statusCode case final statusCode?) {
      return 'YouTube returned HTTP $statusCode while downloading the stream.';
    }

    return 'The stream download failed: ${error.message ?? 'unknown error'}';
  }

  String _sanitizeFileName(String title) {
    final sanitized = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    if (sanitized.isEmpty) {
      return 'pulltube_download';
    }

    return sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
  }

  void _logVideoHeader(VideoInfo videoInfo) {
    debugPrint('[PullTube] video id: ${videoInfo.id}');
    debugPrint('[PullTube] video title: ${videoInfo.title}');
  }

  void _logMuxedStreams(Iterable<MuxedStreamInfo> streams) {
    debugPrint('[PullTube] muxed streams found: ${streams.length}');
    for (final stream in streams) {
      debugPrint(
        '[PullTube]   muxed ${stream.videoResolution.height}p'
        ' | ${stream.container.name}'
        ' | ${stream.size.totalMegaBytes.toStringAsFixed(1)} MB',
      );
    }
  }

  void _logVideoOnlyStreams(Iterable<VideoOnlyStreamInfo> streams) {
    debugPrint('[PullTube] videoOnly streams found: ${streams.length}');
    for (final stream in streams) {
      debugPrint(
        '[PullTube]   videoOnly ${stream.videoResolution.height}p'
        ' | ${stream.container.name}'
        ' | ${stream.size.totalMegaBytes.toStringAsFixed(1)} MB',
      );
    }
  }

  void _logAudioOnlyStreams(Iterable<AudioOnlyStreamInfo> streams) {
    debugPrint('[PullTube] audioOnly streams found: ${streams.length}');
    for (final stream in streams) {
      debugPrint(
        '[PullTube]   audioOnly ${stream.bitrate.kiloBitsPerSecond.round()} kbps'
        ' | ${stream.container.name}'
        ' | ${stream.size.totalMegaBytes.toStringAsFixed(1)} MB',
      );
    }
  }

  void _logFinalOptions({
    required List<StreamOption> videoOptions,
    required List<StreamOption> audioOptions,
  }) {
    debugPrint('[PullTube] final deduplicated options sent to UI:');
    for (final option in videoOptions) {
      debugPrint('[PullTube]   video ${option.label} -> ${option.detail}');
    }
    for (final option in audioOptions) {
      debugPrint('[PullTube]   audio ${option.label} -> ${option.detail}');
    }
  }

  void dispose() {
    _dio.close(force: true);
    _youtube.close();
  }
}

class _SpeedTracker {
  int _lastBytes = 0;
  DateTime _lastSample = DateTime.now();
  double lastSpeed = 0;

  double sample(int receivedBytes) {
    final now = DateTime.now();
    final elapsedMilliseconds = now.difference(_lastSample).inMilliseconds;

    if (elapsedMilliseconds < 250) {
      return lastSpeed;
    }

    final byteDelta = receivedBytes - _lastBytes;
    if (byteDelta > 0) {
      lastSpeed = byteDelta / (elapsedMilliseconds / 1000) / (1024 * 1024);
    }

    _lastBytes = receivedBytes;
    _lastSample = now;
    return lastSpeed;
  }
}
