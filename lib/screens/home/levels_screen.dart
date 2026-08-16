import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/avatar_option.dart';
import '../../models/content_item.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blocky_avatar.dart';
import '../../widgets/star_row.dart';
import '../game/game_screen.dart';

/// The levels screen — a winding roadmap (like a video game's level map)
/// instead of a plain card grid: a path connecting levels, the selected
/// character (in its real colors) standing on the current level as a "you
/// are here" marker, and stars for each completed level shown on the path
/// itself.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, required this.childId, required this.group});

  final String childId;
  final ContentGroup group;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  static const double _nodeSpacing = 200;
  static const double _nodeSize = 84;
  static const double _topPadding = 40;

  final _scrollController = ScrollController();
  bool _scrolledToCurrent = false;

  /// A winding horizontal coordinate (0..1) for each level — a regular S
  /// pattern like familiar level maps (center, right, center, left...).
  double _xFraction(int index) => 0.5 + 0.32 * math.sin(index * math.pi / 2);

  void _scrollToIndexIfNeeded(int index, int total) {
    if (_scrolledToCurrent || !_scrollController.hasClients) return;
    _scrolledToCurrent = true;
    final target = (_topPadding + index * _nodeSpacing - 220).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final child = profileService.children.firstWhere((c) => c.id == widget.childId);
    final avatar = avatarById(child.avatarId);
    final levels = ContentRepository.levelsFor(widget.group);

    // "Current level" = the first unlocked level that isn't completed yet;
    // if all are completed, put the marker on the last level.
    var currentIndex = levels.length - 1;
    for (var i = 0; i < levels.length; i++) {
      final unlocked = child.isLevelUnlocked(widget.group, i);
      final stars = child.starsFor(widget.group, i);
      if (unlocked && stars == 0) {
        currentIndex = i;
        break;
      }
    }

    final totalHeight = _topPadding * 2 + (levels.length - 1) * _nodeSpacing + _nodeSize;
    _scrollToIndexIfNeeded(currentIndex, levels.length);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.group.flagEmoji} ${widget.group.titleAr}')),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: SizedBox(
            width: double.infinity,
            height: totalHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _NaturePainter(totalHeight: totalHeight)),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoadmapPathPainter(
                      count: levels.length,
                      spacing: _nodeSpacing,
                      topPadding: _topPadding,
                      nodeSize: _nodeSize,
                      xFraction: _xFraction,
                    ),
                  ),
                ),
                for (var i = 0; i < levels.length; i++)
                  _LevelNode(
                    top: _topPadding + i * _nodeSpacing,
                    xFraction: _xFraction(i),
                    index: i,
                    unlocked: child.isLevelUnlocked(widget.group, i),
                    stars: child.starsFor(widget.group, i),
                    isCurrent: i == currentIndex,
                    avatar: avatar,
                    nodeSize: _nodeSize,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          childId: widget.childId,
                          group: widget.group,
                          levelIndex: i,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single level node on the path — computes its horizontal position as a
/// fraction of screen width via LayoutBuilder (instead of a fixed position)
/// so it works for any screen size.
class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.top,
    required this.xFraction,
    required this.index,
    required this.unlocked,
    required this.stars,
    required this.isCurrent,
    required this.avatar,
    required this.nodeSize,
    required this.onTap,
  });

  final double top;
  final double xFraction;
  final int index;
  final bool unlocked;
  final int stars;
  final bool isCurrent;
  final AvatarOption avatar;
  final double nodeSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      // Fixed height (instead of relying on content) — the bubble + the
      // star row below it; the "you are here" marker is drawn beyond this
      // box's bounds (Clip.none), so it doesn't need space within the
      // height itself.
      height: nodeSize + 90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth * xFraction;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: centerX - nodeSize / 2,
                top: 0,
                width: nodeSize,
                height: nodeSize + 36, // The circle + spacing + the big star row below it.
                child: _NodeBubble(
                  index: index,
                  unlocked: unlocked,
                  stars: stars,
                  isCurrent: isCurrent,
                  size: nodeSize,
                  onTap: unlocked ? onTap : null,
                ),
              ),
              if (isCurrent)
                Positioned(
                  left: centerX - 22,
                  top: -30,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        BlockyAvatarPreview(avatar: avatar, scale: 0.5),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NodeBubble extends StatelessWidget {
  const _NodeBubble({
    required this.index,
    required this.unlocked,
    required this.stars,
    required this.isCurrent,
    required this.size,
    required this.onTap,
  });

  final int index;
  final bool unlocked;
  final int stars;
  final bool isCurrent;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final completed = stars > 0;
    final Color fill = !unlocked
        ? AppColors.surfaceLight
        : completed
            ? AppColors.green
            : isCurrent
                ? AppColors.yellow
                : AppColors.blue;
    final Color borderColor = isCurrent && unlocked ? AppColors.yellow : AppColors.ink;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: isCurrent ? 4 : 3),
              boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 6), blurRadius: 0)],
            ),
            alignment: Alignment.center,
            child: !unlocked
                ? const Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 30)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textLight),
                  ),
          ),
          const SizedBox(height: 6),
          if (unlocked) StarRow(earned: stars, size: 22),
        ],
      ),
    );
  }
}

/// A dashed line connecting level centers along the path (same visual
/// identity colors — black borders) — drawn behind the nodes.
class _RoadmapPathPainter extends CustomPainter {
  _RoadmapPathPainter({
    required this.count,
    required this.spacing,
    required this.topPadding,
    required this.nodeSize,
    required this.xFraction,
  });

  final int count;
  final double spacing;
  final double topPadding;
  final double nodeSize;
  final double Function(int) xFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;
    final paint = Paint()
      ..color = AppColors.surfaceLight
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset centerFor(int i) => Offset(size.width * xFraction(i), topPadding + i * spacing + nodeSize / 2);

    for (var i = 0; i < count - 1; i++) {
      _drawDashedLine(canvas, centerFor(i), centerFor(i + 1), paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 14.0;
    const gapLength = 10.0;
    final total = (b - a).distance;
    final direction = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segmentEnd = math.min(drawn + dashLength, total);
      canvas.drawLine(a + direction * drawn, a + direction * segmentEnd, paint);
      drawn += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadmapPathPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.spacing != spacing;
}

/// A blocky nature background (simple trees and bushes, colored boxes
/// matching the game world's visual identity) behind the path — a fixed
/// seed (Random(7)) so positions don't change on every repaint, scattered
/// near the screen edges so they don't crowd the path and nodes.
class _NaturePainter extends CustomPainter {
  _NaturePainter({required this.totalHeight});

  final double totalHeight;

  static const _trunkColor = Color(0xFF5A3D23);
  static const _canopyColors = [Color(0xFF1F5C38), Color(0xFF267046), Color(0xFF184A2C)];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final treeCount = (totalHeight / 130).round();

    for (var i = 0; i < treeCount; i++) {
      final onLeft = random.nextBool();
      final marginFraction = 0.04 + random.nextDouble() * 0.10;
      final x = onLeft ? size.width * marginFraction : size.width * (1 - marginFraction);
      final y = random.nextDouble() * totalHeight;
      final scale = 0.7 + random.nextDouble() * 0.6;
      _drawTree(canvas, Offset(x, y), scale, _canopyColors[i % _canopyColors.length], random);
    }
  }

  void _drawTree(Canvas canvas, Offset base, double scale, Color canopyColor, math.Random random) {
    final trunkPaint = Paint()..color = _trunkColor;
    final canopyPaint = Paint()..color = canopyColor.withValues(alpha: 0.8);

    final trunkWidth = 10.0 * scale;
    final trunkHeight = 26.0 * scale;
    final trunkRect = Rect.fromLTWH(base.dx - trunkWidth / 2, base.dy - trunkHeight, trunkWidth, trunkHeight);
    canvas.drawRect(trunkRect, trunkPaint);

    final canopySize = 46.0 * scale;
    final canopyRect = Rect.fromCenter(
      center: Offset(base.dx, base.dy - trunkHeight - canopySize * 0.32),
      width: canopySize,
      height: canopySize * 0.75,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(canopyRect, Radius.circular(6 * scale)), canopyPaint);

    // A second, smaller block on top of the first gives a "stacked blocks"
    // feel instead of a single box.
    final topRect = Rect.fromCenter(
      center: Offset(base.dx, canopyRect.top + 6 * scale),
      width: canopySize * 0.6,
      height: canopySize * 0.45,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(topRect, Radius.circular(5 * scale)), canopyPaint);
  }

  @override
  bool shouldRepaint(covariant _NaturePainter oldDelegate) => oldDelegate.totalHeight != totalHeight;
}
