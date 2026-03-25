import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';

/// Animated sound-wave bars displayed in MP3 / audio mode.
class SoundWaveWidget extends StatefulWidget {
  final double size;

  const SoundWaveWidget({super.key, this.size = 36});

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
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(_controller.value),
        size: Size(widget.size * 1.4, widget.size),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;

  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 7;
    const barWidth = 3.0;
    final gap = (size.width - barCount * barWidth) / (barCount - 1);

    final paint = Paint()
      ..color = AppColors.accentAudio
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < barCount; i++) {
      final phase = (i / barCount) * math.pi * 2;
      final wave = math.sin(t * math.pi * 2 + phase);
      final heightFactor = 0.25 + 0.65 * ((wave + 1) / 2);
      final h = size.height * heightFactor;
      final x = i * (barWidth + gap) + barWidth / 2;
      final yTop = (size.height - h) / 2;

      canvas.drawLine(
        Offset(x, yTop),
        Offset(x, yTop + h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}
