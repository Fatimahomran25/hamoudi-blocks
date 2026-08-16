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

/// شاشة المستويات — خريطة/رود ماب متعرّجة (زي خرائط مستويات الألعاب)
/// بدل شبكة كروت عادية: مسار يوصل بين المستويات، الشخصية المختارة
/// (بألوانها الحقيقية) واقفة على المستوى الحالي كعلامة "انتِ هنا"، ونجوم
/// كل مستوى مكتمل ظاهرة عالمسار نفسه.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, required this.childId, required this.group});

  final String childId;
  final ContentGroup group;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  static const double _nodeSpacing = 150;
  static const double _nodeSize = 84;
  static const double _topPadding = 40;

  final _scrollController = ScrollController();
  bool _scrolledToCurrent = false;

  /// إحداثية أفقية متعرّجة (0..1) لكل مستوى — نمط S منتظم زي خرائط
  /// المستويات المعروفة (وسط، يمين، وسط، يسار...).
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

    // "المستوى الحالي" = أول مستوى مفتوح لسا ما اكتمل؛ لو كلها اكتملت
    // نخلي العلامة على آخر مستوى.
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

/// عقدة مستوى وحدة على المسار — تحسب موقعها الأفقي نسبة لعرض الشاشة عبر
/// LayoutBuilder (بدل موقع ثابت) عشان تنفع أي حجم شاشة.
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
      // ارتفاع ثابت (بدل الاعتماد على المحتوى) — الفقّاعة + صف النجوم تحته؛
      // علامة "انتِ هنا" تُرسم فوق حدود هالصندوق (Clip.none)، ما تحتاج
      // مساحة داخل الارتفاع نفسه.
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
                height: nodeSize + 26, // الدائرة + المسافة + صف النجوم تحتها.
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
                  left: centerX - 26,
                  top: -46,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        BlockyAvatarPreview(avatar: avatar, scale: 0.62),
                        const SizedBox(height: 2),
                        const Text('👇 انتِ هنا', style: TextStyle(fontSize: 11, color: AppColors.yellow)),
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
          if (unlocked) StarRow(earned: stars, size: 14),
        ],
      ),
    );
  }
}

/// خط متقطّع يوصل بين مراكز المستويات على المسار (نفس ألوان الهوية —
/// حدود سوداء) — يُرسم خلف العقد.
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
