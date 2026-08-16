import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/content_item.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../../widgets/star_row.dart';
import '../home/levels_screen.dart';
import 'game_screen.dart';

/// شاشة إنهاء المستوى: فوز (تهنئة + نجوم) أو "حاول مرة ثانية" (بدون قفل
/// رجوع للخلف — فقط إعادة نفس العنصر بقلوب جديدة). لا يوجد "Game Over"
/// نهائي بهالتصميم أبداً.
class LevelResultScreen extends StatefulWidget {
  const LevelResultScreen({
    super.key,
    required this.childId,
    required this.group,
    required this.levelIndex,
    required this.didWin,
    required this.heartsRemaining,
    this.resumeRoundIndex = 0,
  });

  final String childId;
  final ContentGroup group;
  final int levelIndex;
  final bool didWin;

  /// عدد القلوب المتبقية عند الفوز (1-3) — يحدد عدد النجوم:
  /// 3 قلوب=4 نجوم، قلبين=3 نجوم، قلب وحد=نجمتين.
  final int heartsRemaining;

  /// (عند didWin=false بس) رقم العنصر (0-3) اللي خلصت فيه القلوب — يُمرَّر
  /// لزر "حاول مرة ثانية" عشان نستأنف نفس السؤال بدل إعادة المستوى كامل.
  final int resumeRoundIndex;

  @override
  State<LevelResultScreen> createState() => _LevelResultScreenState();
}

class _LevelResultScreenState extends State<LevelResultScreen> {
  bool _saved = false;

  int get _starsEarned => widget.didWin ? (widget.heartsRemaining + 1).clamp(2, 4) : 0;

  @override
  void initState() {
    super.initState();
    if (widget.didWin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveResult());
    }
  }

  Future<void> _saveResult() async {
    if (_saved) return;
    _saved = true;
    await context.read<ProfileService>().recordLevelResult(
          childId: widget.childId,
          group: widget.group,
          levelIndex: widget.levelIndex,
          starsEarned: _starsEarned,
        );
  }

  @override
  Widget build(BuildContext context) {
    final totalLevels = ContentRepository.levelsFor(widget.group).length;
    final hasNextLevel = widget.didWin && widget.levelIndex + 1 < totalLevels;

    return Scaffold(
      body: SafeArea(
        // بوضع landscape (عرض) الارتفاع المتاح أقل بكثير — SingleChildScrollView
        // تضمن إن الزر ("المستوى التالي"...) يفضل يوصله الطفل بالتمرير
        // بدل ما ينقص/يُقصّ من الشاشة (كان بق حقيقي هنا، تم تصحيحه).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.didWin ? '🎉' : '💪',
                style: const TextStyle(fontSize: 88),
              ),
              const SizedBox(height: 12),
              Text(
                widget.didWin ? 'أحسنت يا بطل!' : 'قربت توصل يا بطل!',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                widget.didWin ? 'خلّصت المستوى بنجاح 🌟' : 'جرب مرة ثانية، أنت تقدر! 💪',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 24),
              if (widget.didWin) StarRow(earned: _starsEarned, size: 40),
              const SizedBox(height: 40),
              if (widget.didWin) ...[
                if (hasNextLevel)
                  BigButton(
                    label: 'المستوى التالي',
                    emoji: '➡️',
                    color: AppColors.green,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          childId: widget.childId,
                          group: widget.group,
                          levelIndex: widget.levelIndex + 1,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                BigButton(
                  label: 'كل المستويات',
                  emoji: '🗺️',
                  color: AppColors.blue,
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => LevelsScreen(childId: widget.childId, group: widget.group),
                    ),
                    (route) => route.isFirst,
                  ),
                ),
              ] else
                BigButton(
                  label: 'حاول مرة ثانية',
                  emoji: '🔁',
                  color: AppColors.red,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        childId: widget.childId,
                        group: widget.group,
                        levelIndex: widget.levelIndex,
                        startRoundIndex: widget.resumeRoundIndex,
                      ),
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
