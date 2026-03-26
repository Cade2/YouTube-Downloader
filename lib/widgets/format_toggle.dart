import 'package:flutter/material.dart';

import '../main.dart';
import '../models/video_info.dart';

class FormatToggle extends StatelessWidget {
  const FormatToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MediaFormat selected;
  final ValueChanged<MediaFormat>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isAudio = selected == MediaFormat.mp3;
    final accent = isAudio
        ? PullTubeColors.audioAccent
        : PullTubeColors.videoAccent;

    return Container(
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PullTubeColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth - 6) / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: isAudio ? segmentWidth : 0,
                top: 0,
                child: Container(
                  width: segmentWidth,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.96),
                        accent.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _FormatSegment(
                      label: 'MP4',
                      icon: Icons.ondemand_video_rounded,
                      active: selected == MediaFormat.mp4,
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(MediaFormat.mp4),
                    ),
                  ),
                  Expanded(
                    child: _FormatSegment(
                      label: 'MP3',
                      icon: Icons.graphic_eq_rounded,
                      active: selected == MediaFormat.mp3,
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(MediaFormat.mp3),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FormatSegment extends StatelessWidget {
  const _FormatSegment({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? Colors.white : PullTubeColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : PullTubeColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
