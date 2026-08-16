import 'package:flutter/material.dart';

import '../models/avatar_option.dart';
import '../theme/app_theme.dart';

/// A simple blocky preview (head + torso + 2 arms + 2 legs, colored boxes
/// with black borders) in the same spirit as the 3D game world's
/// character. This is a lightweight 2D representation that's entirely
/// enough for the character-selection screen in Milestone 1 — in
/// Milestone 2 the same [AvatarOption.id] is used to color the real 3D
/// model inside the Three.js world.
class BlockyAvatarPreview extends StatefulWidget {
  const BlockyAvatarPreview({
    super.key,
    required this.avatar,
    this.animate = true,
    this.scale = 1.0,
  });

  final AvatarOption avatar;
  final bool animate;
  final double scale;

  @override
  State<BlockyAvatarPreview> createState() => _BlockyAvatarPreviewState();
}

class _BlockyAvatarPreviewState extends State<BlockyAvatarPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.avatar;
    const block = Border.fromBorderSide(BorderSide(color: AppColors.ink, width: 2.5));

    Widget box({required double w, required double h, required Color color, BorderRadius? radius}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          border: block,
          borderRadius: radius ?? BorderRadius.circular(6),
        ),
      );
    }

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Head + hair
        Stack(
          alignment: Alignment.topCenter,
          children: [
            box(w: 46, h: 40, color: a.skinColor, radius: BorderRadius.circular(10)),
            Positioned(
              top: -8,
              child: box(w: 50, h: 16, color: a.hairColor, radius: BorderRadius.circular(8)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Torso + arms
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box(w: 16, h: 46, color: a.jacketColor),
            const SizedBox(width: 3),
            box(w: 32, h: 52, color: a.jacketColor, radius: BorderRadius.circular(8)),
            const SizedBox(width: 3),
            box(w: 16, h: 46, color: a.jacketColor),
          ],
        ),
        const SizedBox(height: 4),
        // Legs
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            box(w: 18, h: 26, color: AppColors.ink.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            box(w: 18, h: 26, color: AppColors.ink.withValues(alpha: 0.85)),
          ],
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final bob = widget.animate ? (_controller.value * 8) : 0.0;
        return Transform.translate(
          offset: Offset(0, -bob),
          child: Transform.scale(scale: widget.scale, child: child),
        );
      },
      child: body,
    );
  }
}
