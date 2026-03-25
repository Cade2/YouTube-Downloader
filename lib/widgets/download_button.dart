import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import 'format_toggle.dart';

class DownloadButton extends StatelessWidget {
  final MediaFormat format;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const DownloadButton({
    super.key,
    required this.format,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isAudio = format == MediaFormat.mp3;
    final accentColor = isAudio ? AppColors.accentAudio : AppColors.accent;
    final gradientColors = isAudio
        ? [const Color(0xFFFFB800), const Color(0xFFFF8C00)]
        : [const Color(0xFFFF3B3B), const Color(0xFFCC1A1A)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 58,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isEnabled
            ? LinearGradient(colors: gradientColors)
            : null,
        color: isEnabled ? null : AppColors.card,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onPressed : null,
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.black.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAudio ? Icons.audio_file_rounded : Icons.download_rounded,
                color: isEnabled ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isAudio ? 'Download MP3' : 'Download MP4',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? Colors.white : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
