import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum MediaFormat { mp4, mp3 }

extension MediaFormatX on MediaFormat {
  bool get isAudio => this == MediaFormat.mp3;

  String get label => isAudio ? 'MP3' : 'MP4';

  String get selectionLabel => isAudio ? 'Bitrate' : 'Quality';

  String get actionLabel => isAudio ? 'Save to Files' : 'Save to Gallery';
}

class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.duration,
  });

  factory VideoInfo.fromVideo(Video video) {
    final thumbnails = video.thumbnails;
    final thumbnailUrl =
        [
          thumbnails.maxResUrl,
          thumbnails.highResUrl,
          thumbnails.standardResUrl,
          thumbnails.mediumResUrl,
          thumbnails.lowResUrl,
        ].firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => thumbnails.mediumResUrl,
        );

    return VideoInfo(
      id: video.id.value,
      title: video.title,
      channelName: video.author,
      thumbnailUrl: thumbnailUrl,
      duration: video.duration ?? Duration.zero,
    );
  }

  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final Duration duration;

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '${duration.inMinutes}:$seconds';
  }
}

class StreamOption {
  const StreamOption({
    required this.label,
    required this.detail,
    required this.streamInfo,
    required this.sortValue,
    required this.container,
    required this.fileExtension,
    required this.hasAudio,
    required this.isMuxed,
  });

  final String label;
  final String detail;
  final StreamInfo streamInfo;
  final int sortValue;
  final String container;
  final String fileExtension;
  final bool hasAudio;
  final bool isMuxed;

  bool get isGalleryCompatible => fileExtension == 'mp4';
}
