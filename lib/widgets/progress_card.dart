import 'package:flutter/material.dart';

import '../main.dart';
import '../models/video_info.dart';
import '../services/youtube_service.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.progress, required this.format});

  final DownloadProgress progress;
  final MediaFormat format;

  @override
  Widget build(BuildContext context) {
    final isAudio = format == MediaFormat.mp3;
    final accent = isAudio
        ? PullTubeColors.audioAccent
        : PullTubeColors.videoAccent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAudio
                    ? Icons.folder_open_rounded
                    : Icons.photo_library_rounded,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAudio ? 'Saving into Files' : 'Saving into Photo Library',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                progress.percentLabel,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            progress.stageLabel,
            style: const TextStyle(
              color: PullTubeColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.progress),
            duration: const Duration(milliseconds: 180),
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: value,
                  backgroundColor: PullTubeColors.surfaceSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ProgressStat(
                label: 'Transfer',
                value: progress.transferredLabel,
              ),
              const SizedBox(width: 12),
              _ProgressStat(
                label: 'Speed',
                value: '${progress.speedInMegabytes.toStringAsFixed(2)} MB/s',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PullTubeColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PullTubeColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: PullTubeColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
