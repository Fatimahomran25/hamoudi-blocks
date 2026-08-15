import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/content_item.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/star_row.dart';
import '../game/game_screen.dart';

/// شبكة كروت المستويات: كل مستوى 4 عناصر، مقفل حتى يكمل اللي قبله،
/// يعرض النجوم المكتسبة (من 4).
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key, required this.childId, required this.group});

  final String childId;
  final ContentGroup group;

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final child = profileService.children.firstWhere((c) => c.id == childId);
    final levels = ContentRepository.levelsFor(group);

    return Scaffold(
      appBar: AppBar(title: Text('${group.flagEmoji} ${group.titleAr}')),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.9,
          ),
          itemCount: levels.length,
          itemBuilder: (context, index) {
            final unlocked = child.isLevelUnlocked(group, index);
            final stars = child.starsFor(group, index);
            return GestureDetector(
              onTap: unlocked
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameScreen(
                            childId: childId,
                            group: group,
                            levelIndex: index,
                          ),
                        ),
                      )
                  : null,
              child: NeoBox(
                color: unlocked ? AppColors.surface : AppColors.surfaceLight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (unlocked) ...[
                      Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StarRow(earned: stars, size: 16),
                    ] else
                      const Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 34),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
