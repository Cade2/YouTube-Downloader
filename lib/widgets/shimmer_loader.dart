import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart';

class ShimmerLoader extends StatelessWidget {
  const ShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: PullTubeColors.surface,
      highlightColor: PullTubeColors.surfaceSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ShimmerBlock(height: 254, radius: 28),
          SizedBox(height: 18),
          _ShimmerBlock(height: 68, radius: 24),
          SizedBox(height: 16),
          _ShimmerBlock(height: 116, radius: 24),
          SizedBox(height: 16),
          _ShimmerBlock(height: 62, radius: 22),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
