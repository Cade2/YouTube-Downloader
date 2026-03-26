import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    this.stageLabel = 'Preparing download...',
  });

  const DownloadProgress.zero()
    : progress = 0,
      speedInMegabytes = 0,
      receivedBytes = 0,
      totalBytes = 0,
      stageLabel = 'Preparing download...';

  final double progress;
  final double speedInMegabytes;
  final int receivedBytes;
  final int totalBytes;
  final String stageLabel;

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
    Directory? workingDirectory;

    try {
      if (format == MediaFormat.mp4) {
        await _ensurePhotoLibraryPermission();
      }

      final temporaryDirectory = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(videoInfo.title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseFileStem = '${safeName}_$timestamp';
      workingDirectory = await Directory(
        '${temporaryDirectory.path}/pulltube_$timestamp',
      ).create(recursive: true);

      if (format == MediaFormat.mp4) {
        return _downloadVideoSelection(
          videoInfo: videoInfo,
          option: option,
          workingDirectory: workingDirectory,
          baseFileStem: baseFileStem,
          onProgress: onProgress,
        );
      }

      return _downloadAudioSelection(
        option: option,
        workingDirectory: workingDirectory,
        baseFileStem: baseFileStem,
        onProgress: onProgress,
      );
    } on DioException catch (error) {
      throw YouTubeServiceException(_mapDioException(error));
    } on YouTubeServiceException {
      rethrow;
    } on FileSystemException catch (error) {
      throw YouTubeServiceException('File saving failed: ${error.message}');
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '[PullTube] platform exception during download flow: '
        '${error.code} | ${error.message} | ${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw const YouTubeServiceException(
        'Couldn\'t complete the download on iPhone right now.',
      );
    } catch (error, stackTrace) {
      debugPrint('[PullTube] unexpected download error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const YouTubeServiceException('Download failed unexpectedly.');
    } finally {
      await _deleteDirectoryQuietly(workingDirectory);
    }
  }

  Future<DownloadResult> _downloadAudioSelection({
    required StreamOption option,
    required Directory workingDirectory,
    required String baseFileStem,
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    final fileName = '$baseFileStem.${option.fileExtension}';
    final temporaryFile = File('${workingDirectory.path}/$fileName');
    final totalBytes = _streamSize(option.streamInfo);

    await _downloadStreamToFile(
      streamInfo: option.streamInfo,
      destination: temporaryFile,
      stageLabel: 'Downloading audio...',
      startProgress: 0,
      endProgress: 0.92,
      baseReceivedBytes: 0,
      totalBytes: totalBytes,
      onProgress: onProgress,
    );

    _emitProgress(
      onProgress: onProgress,
      stageLabel: 'Saving into Files...',
      progress: 0.97,
      speedInMegabytes: 0,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
    );

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final savedFile = File('${documentsDirectory.path}/$fileName');

    if (await savedFile.exists()) {
      await savedFile.delete();
    }

    final persistedFile = await temporaryFile.copy(savedFile.path);

    _emitProgress(
      onProgress: onProgress,
      stageLabel: 'Saved into Files',
      progress: 1,
      speedInMegabytes: 0,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
    );

    return DownloadResult(savedToGallery: false, filePath: persistedFile.path);
  }

  Future<DownloadResult> _downloadVideoSelection({
    required VideoInfo videoInfo,
    required StreamOption option,
    required Directory workingDirectory,
    required String baseFileStem,
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    final galleryFileName = '$baseFileStem.mp4';

    if (option.streamInfo case final MuxedStreamInfo selectedStream) {
      _logSelectedVideoStream(
        option: option,
        streamKind: 'muxed',
        container: selectedStream.container.name,
        videoCodec: selectedStream.videoCodec,
        audioCodec: selectedStream.audioCodec,
        sizeInBytes: selectedStream.size.totalBytes,
      );

      final totalBytes = _streamSize(selectedStream);
      final downloadedFile = File(
        '${workingDirectory.path}/$baseFileStem.${option.fileExtension}',
      );

      debugPrint('[PullTube] temp video path: ${downloadedFile.path}');

      await _downloadStreamToFile(
        streamInfo: selectedStream,
        destination: downloadedFile,
        stageLabel: 'Downloading video with audio...',
        startProgress: 0,
        endProgress: 0.9,
        baseReceivedBytes: 0,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );

      File finalFile = downloadedFile;
      final needsFinalization =
          !option.isGalleryCompatible ||
          !_isMp4FriendlyVideoCodec(selectedStream.videoCodec) ||
          !_isMp4FriendlyAudioCodec(selectedStream.audioCodec);

      if (needsFinalization) {
        final finalizedFile = File('${workingDirectory.path}/$galleryFileName');
        debugPrint('[PullTube] final merged file path: ${finalizedFile.path}');

        finalFile = await _finalizeMuxedVideoAsMp4(
          sourceFile: downloadedFile,
          outputFile: finalizedFile,
          stageLabel: 'Finalizing MP4 file...',
          totalBytes: totalBytes,
          onProgress: onProgress,
          videoCodec: selectedStream.videoCodec,
          audioCodec: selectedStream.audioCodec,
        );
      }

      await _saveVideoToPhotoLibrary(
        file: finalFile,
        title: galleryFileName,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );

      return const DownloadResult(savedToGallery: true);
    }

    if (option.streamInfo case final VideoOnlyStreamInfo selectedVideoStream) {
      _logSelectedVideoStream(
        option: option,
        streamKind: 'video-only',
        container: selectedVideoStream.container.name,
        videoCodec: selectedVideoStream.videoCodec,
        audioCodec: null,
        sizeInBytes: selectedVideoStream.size.totalBytes,
      );

      final manifest = await _youtube.videos.streamsClient.getManifest(
        videoInfo.id,
      );
      final selectedAudioStream = _selectBestAudioStream(manifest.audioOnly);

      if (selectedAudioStream == null) {
        throw const YouTubeServiceException(
          'Couldn\'t find an audio stream to pair with this video quality.',
        );
      }

      _logSelectedAudioStream(selectedAudioStream);

      final videoBytes = _streamSize(selectedVideoStream);
      final audioBytes = _streamSize(selectedAudioStream);
      final totalBytes = videoBytes + audioBytes;

      final videoFile = File(
        '${workingDirectory.path}/${baseFileStem}_video.${option.fileExtension}',
      );
      final audioFile = File(
        '${workingDirectory.path}/${baseFileStem}_audio.'
        '${_audioFileExtension(selectedAudioStream)}',
      );
      final mergedFile = File('${workingDirectory.path}/$galleryFileName');

      debugPrint('[PullTube] temp video path: ${videoFile.path}');
      debugPrint('[PullTube] temp audio path: ${audioFile.path}');
      debugPrint('[PullTube] final merged file path: ${mergedFile.path}');

      await _downloadStreamToFile(
        streamInfo: selectedVideoStream,
        destination: videoFile,
        stageLabel: 'Downloading high-quality video...',
        startProgress: 0,
        endProgress: 0.68,
        baseReceivedBytes: 0,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );

      await _downloadStreamToFile(
        streamInfo: selectedAudioStream,
        destination: audioFile,
        stageLabel: 'Downloading companion audio...',
        startProgress: 0.68,
        endProgress: 0.86,
        baseReceivedBytes: videoBytes,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );

      final finalizedFile = await _mergeVideoAndAudioAsMp4(
        videoFile: videoFile,
        audioFile: audioFile,
        outputFile: mergedFile,
        totalBytes: totalBytes,
        onProgress: onProgress,
        videoCodec: selectedVideoStream.videoCodec,
        audioCodec: selectedAudioStream.audioCodec,
      );

      await _saveVideoToPhotoLibrary(
        file: finalizedFile,
        title: galleryFileName,
        totalBytes: totalBytes,
        onProgress: onProgress,
      );

      return const DownloadResult(savedToGallery: true);
    }

    throw const YouTubeServiceException(
      'This video stream could not be prepared for MP4 download.',
    );
  }

  Future<void> _downloadStreamToFile({
    required StreamInfo streamInfo,
    required File destination,
    required String stageLabel,
    required double startProgress,
    required double endProgress,
    required int baseReceivedBytes,
    required int totalBytes,
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    final speedTracker = _SpeedTracker();
    final fallbackTotal = _streamSize(streamInfo);

    await _dio.downloadUri(
      streamInfo.url,
      destination.path,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        final streamTotal = total > 0 ? total : fallbackTotal;
        final stageProgress = streamTotal > 0 ? received / streamTotal : 0.0;
        final overallProgress =
            startProgress + ((endProgress - startProgress) * stageProgress);

        _emitProgress(
          onProgress: onProgress,
          stageLabel: stageLabel,
          progress: overallProgress,
          speedInMegabytes: speedTracker.sample(received),
          receivedBytes: _boundedBytes(
            baseReceivedBytes + received,
            totalBytes,
          ),
          totalBytes: totalBytes,
        );
      },
      options: Options(
        followRedirects: true,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    _emitProgress(
      onProgress: onProgress,
      stageLabel: stageLabel,
      progress: endProgress,
      speedInMegabytes: speedTracker.lastSpeed,
      receivedBytes: _boundedBytes(
        baseReceivedBytes + fallbackTotal,
        totalBytes,
      ),
      totalBytes: totalBytes,
    );
  }

  Future<File> _mergeVideoAndAudioAsMp4({
    required File videoFile,
    required File audioFile,
    required File outputFile,
    required int totalBytes,
    required void Function(DownloadProgress progress) onProgress,
    required String videoCodec,
    required String audioCodec,
  }) async {
    _emitProgress(
      onProgress: onProgress,
      stageLabel: 'Merging audio and video...',
      progress: 0.9,
      speedInMegabytes: 0,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
    );

    final shouldCopy =
        _isMp4FriendlyVideoCodec(videoCodec) &&
        _isMp4FriendlyAudioCodec(audioCodec);

    if (shouldCopy) {
      final mergedWithCopy = await _runFfmpegCommand(
        command:
            '-y -i ${_quotePath(videoFile.path)} '
            '-i ${_quotePath(audioFile.path)} '
            '-map 0:v:0 -map 1:a:0 '
            '-c:v copy -c:a copy -shortest -movflags +faststart '
            '${_quotePath(outputFile.path)}',
        logLabel: 'mux command',
        failureMessage: 'Couldn\'t merge audio and video.',
        allowFallback: true,
      );

      if (mergedWithCopy && await _hasUsableFile(outputFile)) {
        _emitProgress(
          onProgress: onProgress,
          stageLabel: 'Merged audio and video',
          progress: 0.97,
          speedInMegabytes: 0,
          receivedBytes: totalBytes,
          totalBytes: totalBytes,
        );
        return outputFile;
      }
    }

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final transcoded = await _runFfmpegCommand(
      command:
          '-y -i ${_quotePath(videoFile.path)} '
          '-i ${_quotePath(audioFile.path)} '
          '-map 0:v:0 -map 1:a:0 '
          '-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p '
          '-c:a aac -b:a 192k -shortest -movflags +faststart '
          '${_quotePath(outputFile.path)}',
      logLabel: 'merge fallback command',
      failureMessage: 'Couldn\'t merge audio and video.',
    );

    if (!transcoded || !await _hasUsableFile(outputFile)) {
      throw const YouTubeServiceException('Couldn\'t merge audio and video.');
    }

    _emitProgress(
      onProgress: onProgress,
      stageLabel: 'Merged audio and video',
      progress: 0.97,
      speedInMegabytes: 0,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
    );

    return outputFile;
  }

  Future<File> _finalizeMuxedVideoAsMp4({
    required File sourceFile,
    required File outputFile,
    required String stageLabel,
    required int totalBytes,
    required void Function(DownloadProgress progress) onProgress,
    required String videoCodec,
    required String audioCodec,
  }) async {
    _emitProgress(
      onProgress: onProgress,
      stageLabel: stageLabel,
      progress: 0.94,
      speedInMegabytes: 0,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
    );

    final shouldCopy =
        _isMp4FriendlyVideoCodec(videoCodec) &&
        _isMp4FriendlyAudioCodec(audioCodec);

    if (shouldCopy) {
      final remuxed = await _runFfmpegCommand(
        command:
            '-y -i ${_quotePath(sourceFile.path)} '
            '-c:v copy -c:a copy -movflags +faststart '
            '${_quotePath(outputFile.path)}',
        logLabel: 'mux command',
        failureMessage: 'Couldn\'t finalize the video file before saving.',
        allowFallback: true,
      );

      if (remuxed && await _hasUsableFile(outputFile)) {
        return outputFile;
      }
    }

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final transcoded = await _runFfmpegCommand(
      command:
          '-y -i ${_quotePath(sourceFile.path)} '
          '-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p '
          '-c:a aac -b:a 192k -movflags +faststart '
          '${_quotePath(outputFile.path)}',
      logLabel: 'finalize fallback command',
      failureMessage: 'Couldn\'t finalize the video file before saving.',
    );

    if (!transcoded || !await _hasUsableFile(outputFile)) {
      throw const YouTubeServiceException(
        'Couldn\'t finalize the video file before saving.',
      );
    }

    return outputFile;
  }

  Future<bool> _runFfmpegCommand({
    required String command,
    required String logLabel,
    required String failureMessage,
    bool allowFallback = false,
  }) async {
    debugPrint('[PullTube] $logLabel: $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    final output = await session.getOutput();
    final logs = await session.getLogsAsString();
    final failStackTrace = await session.getFailStackTrace();

    debugPrint('[PullTube] merge result code: ${returnCode?.getValue()}');
    if (output != null && output.isNotEmpty) {
      debugPrint('[PullTube] merge output: $output');
    }
    if (logs.isNotEmpty) {
      debugPrint('[PullTube] merge logs: $logs');
    }
    if (failStackTrace != null && failStackTrace.isNotEmpty) {
      debugPrint('[PullTube] merge stack trace: $failStackTrace');
    }

    if (ReturnCode.isSuccess(returnCode)) {
      return true;
    }

    if (allowFallback) {
      return false;
    }

    throw YouTubeServiceException(failureMessage);
  }

  Future<void> _saveVideoToPhotoLibrary({
    required File file,
    required String title,
    required int totalBytes,
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    if (!await _hasUsableFile(file)) {
      throw const YouTubeServiceException(
        'Couldn\'t finalize the video file before saving.',
      );
    }

    _emitProgress(
      onProgress: onProgress,
      stageLabel: 'Saving into Photo Library...',
      progress: 0.99,
      speedInMegabytes: 0,
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
    );

    debugPrint('[PullTube] save attempt path: ${file.path}');
    debugPrint('[PullTube] final save result: attempting title=$title');

    try {
      final asset = await PhotoManager.editor.saveVideo(file, title: title);
      debugPrint(
        '[PullTube] final save result: success '
        'assetId=${asset.id} '
        'title=${asset.title}',
      );

      _emitProgress(
        onProgress: onProgress,
        stageLabel: 'Saved into Photo Library',
        progress: 1,
        speedInMegabytes: 0,
        receivedBytes: totalBytes,
        totalBytes: totalBytes,
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '[PullTube] final save result: platform failure '
        '${error.code} | ${error.message} | ${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw const YouTubeServiceException(
        'Couldn\'t save to Photos. Please allow photo access in Settings.',
      );
    } catch (error, stackTrace) {
      debugPrint('[PullTube] final save result: failure $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const YouTubeServiceException(
        'Couldn\'t save to Photos. Please allow photo access in Settings.',
      );
    }
  }

  Future<void> _ensurePhotoLibraryPermission() async {
    if (!Platform.isIOS) {
      return;
    }

    var addOnlyStatus = await Permission.photosAddOnly.status;
    var fullStatus = await Permission.photos.status;

    debugPrint(
      '[PullTube] photo permission status before request: '
      'addOnly=$addOnlyStatus | full=$fullStatus',
    );

    if (!_hasWritablePhotoPermission(addOnlyStatus, fullStatus)) {
      addOnlyStatus = await Permission.photosAddOnly.request();
      fullStatus = await Permission.photos.status;

      debugPrint(
        '[PullTube] photo permission status after add-only request: '
        'addOnly=$addOnlyStatus | full=$fullStatus',
      );
    }

    final photoManagerState = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.addOnly,
      ),
    );

    debugPrint(
      '[PullTube] photo_manager add-only permission state: $photoManagerState',
    );
    debugPrint(
      '[PullTube] photo access resolved: '
      'addOnlyGranted=${_isGrantedPermission(addOnlyStatus)} '
      '| fullGranted=${_isGrantedPermission(fullStatus)} '
      '| photoManagerAuthorized=${_isAuthorizedPhotoState(photoManagerState)}',
    );

    final hasWritableAccess =
        _hasWritablePhotoPermission(addOnlyStatus, fullStatus) ||
        _isAuthorizedPhotoState(photoManagerState);

    if (!hasWritableAccess) {
      throw const YouTubeServiceException(
        'Couldn\'t save to Photos. Please allow photo access in Settings.',
      );
    }
  }

  AudioOnlyStreamInfo? _selectBestAudioStream(
    Iterable<AudioOnlyStreamInfo> streams,
  ) {
    final sorted = streams.toList()
      ..sort((left, right) {
        final scoreDelta =
            _audioPreferenceScore(right) - _audioPreferenceScore(left);
        if (scoreDelta != 0) {
          return scoreDelta;
        }
        return right.bitrate.bitsPerSecond.compareTo(
          left.bitrate.bitsPerSecond,
        );
      });

    return sorted.isEmpty ? null : sorted.first;
  }

  int _audioPreferenceScore(AudioOnlyStreamInfo stream) {
    final codec = stream.audioCodec.toLowerCase();
    final container = stream.container.name.toLowerCase();
    var score = stream.bitrate.bitsPerSecond;

    if (container == 'mp4') {
      score += 2 * 1000 * 1000;
    }
    if (codec.contains('mp4a') || codec.contains('aac')) {
      score += 1000 * 1000;
    }
    if (stream.audioTrack?.displayName case final displayName?) {
      final normalized = displayName.toLowerCase();
      if (normalized.contains('english') || normalized.contains('original')) {
        score += 250 * 1000;
      }
    }

    return score;
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
      final fileExtension = _audioFileExtension(stream);
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

  int _streamSize(StreamInfo streamInfo) => streamInfo.size.totalBytes;

  int _boundedBytes(int value, int totalBytes) {
    if (totalBytes <= 0) {
      return value;
    }
    return value.clamp(0, totalBytes).toInt();
  }

  String _audioFileExtension(AudioOnlyStreamInfo stream) =>
      stream.container.name == 'mp4' ? 'm4a' : stream.container.name;

  bool _hasWritablePhotoPermission(
    PermissionStatus addOnlyStatus,
    PermissionStatus fullStatus,
  ) {
    return _isGrantedPermission(addOnlyStatus) ||
        _isGrantedPermission(fullStatus);
  }

  bool _isGrantedPermission(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  bool _isAuthorizedPhotoState(PermissionState state) =>
      state == PermissionState.authorized || state == PermissionState.limited;

  bool _isMp4FriendlyVideoCodec(String codec) {
    final normalized = codec.toLowerCase();
    return normalized.contains('avc1') ||
        normalized.contains('h264') ||
        normalized.contains('hev1') ||
        normalized.contains('hvc1') ||
        normalized.contains('mp4v');
  }

  bool _isMp4FriendlyAudioCodec(String codec) {
    final normalized = codec.toLowerCase();
    return normalized.contains('mp4a') ||
        normalized.contains('aac') ||
        normalized.contains('alac');
  }

  String _quotePath(String path) => '"${path.replaceAll('"', '\\"')}"';

  Future<bool> _hasUsableFile(File file) async {
    if (!await file.exists()) {
      return false;
    }
    return await file.length() > 0;
  }

  Future<void> _deleteDirectoryQuietly(Directory? directory) async {
    if (directory == null) {
      return;
    }
    if (!await directory.exists()) {
      return;
    }

    try {
      await directory.delete(recursive: true);
    } catch (error) {
      debugPrint('[PullTube] cleanup skipped: $error');
    }
  }

  void _emitProgress({
    required void Function(DownloadProgress progress) onProgress,
    required String stageLabel,
    required double progress,
    required double speedInMegabytes,
    required int receivedBytes,
    required int totalBytes,
  }) {
    onProgress(
      DownloadProgress(
        progress: progress.clamp(0.0, 1.0).toDouble(),
        speedInMegabytes: speedInMegabytes,
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        stageLabel: stageLabel,
      ),
    );
  }

  void _logVideoHeader(VideoInfo videoInfo) {
    debugPrint('[PullTube] video id: ${videoInfo.id}');
    debugPrint('[PullTube] video title: ${videoInfo.title}');
  }

  void _logSelectedVideoStream({
    required StreamOption option,
    required String streamKind,
    required String container,
    required String videoCodec,
    required String? audioCodec,
    required int sizeInBytes,
  }) {
    debugPrint(
      '[PullTube] selected video stream: '
      '${option.label} | $streamKind | $container | '
      'videoCodec=$videoCodec | '
      'audioCodec=${audioCodec ?? 'none'} | '
      '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
    );
    debugPrint(
      '[PullTube] selected stream has audio: ${option.hasAudio} '
      '| is muxed: ${option.isMuxed}',
    );
  }

  void _logSelectedAudioStream(AudioOnlyStreamInfo stream) {
    debugPrint(
      '[PullTube] selected audio stream: '
      '${stream.bitrate.kiloBitsPerSecond.round()} kbps | '
      '${stream.container.name} | '
      'audioCodec=${stream.audioCodec} | '
      '${stream.size.totalMegaBytes.toStringAsFixed(1)} MB',
    );
  }

  void _logMuxedStreams(Iterable<MuxedStreamInfo> streams) {
    debugPrint('[PullTube] muxed streams found: ${streams.length}');
    for (final stream in streams) {
      debugPrint(
        '[PullTube]   muxed ${stream.videoResolution.height}p'
        ' | ${stream.container.name}'
        ' | videoCodec=${stream.videoCodec}'
        ' | audioCodec=${stream.audioCodec}'
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
        ' | videoCodec=${stream.videoCodec}'
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
        ' | audioCodec=${stream.audioCodec}'
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
