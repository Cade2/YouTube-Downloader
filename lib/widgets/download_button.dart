import 'package:flutter/material.dart';

import '../main.dart';
import '../models/video_info.dart';

class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    required this.format,
    required this.isEnabled,
    required this.isBusy,
    required this.onPressed,
  });

  final MediaFormat format;
  final bool isEnabled;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isAudio = format == MediaFormat.mp3;
    final gradient = isAudio
        ? const [PullTubeColors.audioAccent, PullTubeColors.audioAccentDeep]
        : const [PullTubeColors.videoAccent, PullTubeColors.videoAccentDeep];

    final icon = isAudio ? Icons.audio_file_rounded : Icons.download_rounded;
    final label = isBusy
        ? 'Downloading...'
        : isAudio
        ? 'Download Audio'
        : 'Download Video';

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3),
                blurRadius: 28,
                offset: const Offset(0, 18),
                spreadRadius: -14,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  format.actionLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
