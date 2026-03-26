import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/video_info.dart';
import 'sound_wave_widget.dart';

class VideoInfoCard extends StatelessWidget {
  const VideoInfoCard({
    super.key,
    required this.info,
    required this.accent,
    required this.isAudioMode,
  });

  final VideoInfo info;
  final Color accent;
  final bool isAudioMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: PullTubeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: info.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: PullTubeColors.surfaceSecondary),
                    errorWidget: (context, url, error) => Container(
                      color: PullTubeColors.surfaceSecondary,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: PullTubeColors.textMuted,
                        size: 34,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAudioMode) ...[
                            const SoundWaveWidget(
                              color: PullTubeColors.audioAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            info.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isAudioMode ? 'Audio Extract' : 'Video Ready',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetaChip(
                        icon: Icons.account_circle_rounded,
                        label: info.channelName,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label: info.formattedDuration,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PullTubeColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PullTubeColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: PullTubeColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
