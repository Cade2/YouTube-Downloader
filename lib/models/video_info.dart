import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Metadata about a YouTube video shown in the info card.
class VideoInfo {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;

  const VideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
  });

  factory VideoInfo.fromVideo(Video video) {
    // Pick the best available thumbnail
    final thumbnails = video.thumbnails;
    final thumbUrl = thumbnails.maxResUrl.isNotEmpty
        ? thumbnails.maxResUrl
        : thumbnails.highResUrl.isNotEmpty
            ? thumbnails.highResUrl
            : thumbnails.standardResUrl.isNotEmpty
                ? thumbnails.standardResUrl
                : thumbnails.mediumResUrl;

    return VideoInfo(
      id: video.id.value,
      title: video.title,
      author: video.author,
      thumbnailUrl: thumbUrl,
      duration: video.duration ?? Duration.zero,
    );
  }

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

/// A selectable stream option shown in the quality dropdown.
class StreamOption {
  final String label;
  final StreamInfo streamInfo;

  const StreamOption({
    required this.label,
    required this.streamInfo,
  });
}
