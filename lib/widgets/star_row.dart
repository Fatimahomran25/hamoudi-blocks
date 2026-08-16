import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A row of stars (out of [total]) — used in the levels screen and the win screen.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.earned, this.total = 4, this.size = 22});

  final int earned;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < earned;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? AppColors.yellow : AppColors.textMuted,
          size: size,
        );
      }),
    );
  }
}

/// A row of hearts (remaining attempts in gameplay) — out of [total] = 3 per the prompt.
class HeartRow extends StatelessWidget {
  const HeartRow({super.key, required this.remaining, this.total = 3, this.size = 26});

  final int remaining;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < remaining;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: filled ? AppColors.red : AppColors.textMuted,
            size: size,
          ),
        );
      }),
    );
  }
}
