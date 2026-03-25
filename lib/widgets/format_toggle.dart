import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

enum MediaFormat { mp4, mp3 }

class FormatToggle extends StatelessWidget {
  final MediaFormat selected;
  final ValueChanged<MediaFormat> onChanged;

  const FormatToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAudio = selected == MediaFormat.mp3;
    final accent = isAudio ? AppColors.accentAudio : AppColors.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Sliding pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: isAudio ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              _FormatTab(
                label: 'MP4',
                icon: Icons.videocam_rounded,
                isSelected: !isAudio,
                accent: accent,
                onTap: () => onChanged(MediaFormat.mp4),
              ),
              _FormatTab(
                label: 'MP3',
                icon: Icons.music_note_rounded,
                isSelected: isAudio,
                accent: accent,
                onTap: () => onChanged(MediaFormat.mp3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormatTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _FormatTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
