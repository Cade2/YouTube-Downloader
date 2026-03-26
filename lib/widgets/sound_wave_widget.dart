import 'dart:math' as math;

import 'package:flutter/material.dart';

class SoundWaveWidget extends StatefulWidget {
  const SoundWaveWidget({
    super.key,
    this.color = const Color(0xFFF3B24F),
    this.size = 24,
  });

  final Color color;
  final double size;

  @override
  State<SoundWaveWidget> createState() => _SoundWaveWidgetState();
}

class _SoundWaveWidgetState extends State<SoundWaveWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.size / 7;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final phase = (_controller.value * math.pi * 2) + index;
              final normalized = 0.3 + ((math.sin(phase) + 1) / 2) * 0.7;
              return Container(
                width: barWidth,
                height: widget.size * normalized,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
