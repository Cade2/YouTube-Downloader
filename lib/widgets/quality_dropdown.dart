import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/video_info.dart';
import 'format_toggle.dart';

class QualityDropdown extends StatelessWidget {
  final List<StreamOption> options;
  final StreamOption? selected;
  final ValueChanged<StreamOption> onChanged;
  final MediaFormat format;

  const QualityDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final isAudio = format == MediaFormat.mp3;
    final accent = isAudio ? AppColors.accentAudio : AppColors.accent;
    final labelText = isAudio ? 'Bitrate' : 'Quality';

    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<StreamOption>(
              value: selected,
              isExpanded: true,
              dropdownColor: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: accent,
              ),
              items: options.map((option) {
                final isSelected = option.label == selected?.label;
                return DropdownMenuItem<StreamOption>(
                  value: option,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? accent : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        option.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? accent : Colors.white,
                        ),
                      ),
                      if (options.first.label == option.label) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Best',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (option) {
                if (option != null) onChanged(option);
              },
              selectedItemBuilder: (context) => options.map((option) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    option.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
