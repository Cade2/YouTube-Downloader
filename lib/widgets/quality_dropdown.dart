import 'package:flutter/material.dart';

import '../main.dart';
import '../models/video_info.dart';

class QualityDropdown extends StatelessWidget {
  const QualityDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.format,
    required this.enabled,
    required this.onChanged,
  });

  final List<StreamOption> options;
  final StreamOption? selected;
  final MediaFormat format;
  final bool enabled;
  final ValueChanged<StreamOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isAudio = format == MediaFormat.mp3;
    final accent = isAudio
        ? PullTubeColors.audioAccent
        : PullTubeColors.videoAccent;
    final activeOption = selected ?? (options.isEmpty ? null : options.first);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PullTubeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PullTubeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAudio ? Icons.equalizer_rounded : Icons.high_quality_rounded,
                color: accent,
              ),
              const SizedBox(width: 10),
              Text(
                format.selectionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<StreamOption>(
            initialValue: activeOption,
            items: options
                .map(
                  (option) => DropdownMenuItem<StreamOption>(
                    value: option,
                    child: _DropdownOptionTile(option: option),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
            isExpanded: true,
            borderRadius: BorderRadius.circular(20),
            dropdownColor: PullTubeColors.surfaceSecondary,
            menuMaxHeight: 320,
            decoration: InputDecoration(
              filled: true,
              fillColor: PullTubeColors.surfaceSecondary,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: accent, width: 1.2),
              ),
            ),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
            selectedItemBuilder: (context) {
              return options
                  .map(
                    (option) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        option.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList();
            },
          ),
          if (activeOption != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                activeOption.detail,
                style: const TextStyle(
                  color: PullTubeColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DropdownOptionTile extends StatelessWidget {
  const _DropdownOptionTile({required this.option});

  final StreamOption option;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          option.detail,
          style: const TextStyle(
            color: PullTubeColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
