import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/avatar_option.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../../widgets/blocky_avatar.dart';
import '../../widgets/responsive_center.dart';
import '../settings/voice_settings_screen.dart';
import '../settings/weak_points_screen.dart';
import 'main_menu_screen.dart';

/// The "game login" screen: the first thing the child sees when opening
/// the app after the initial setup — their profile is ready (name +
/// character), without them typing or reading anything.
class GameLoginScreen extends StatelessWidget {
  const GameLoginScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final child = profileService.children.firstWhere(
      (c) => c.id == childId,
      orElse: () => profileService.children.first,
    );
    final avatar = avatarById(child.avatarId);

    return Scaffold(
      body: SafeArea(
        // ResponsiveCenter instead of a plain Column: centers normally in
        // portrait, and becomes scrollable instead of clipping in
        // landscape (was a real bug here).
        child: ResponsiveCenter(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: AppColors.textMuted,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VoiceSettingsScreen(childId: childId),
                  ),
                ),
              ),
            ),
            const Spacer(),
            NeoBox(
              color: avatar.jacketColor.withValues(alpha: 0.18),
              borderRadius: 28,
              padding: const EdgeInsets.all(28),
              child: BlockyAvatarPreview(avatar: avatar, scale: 2.2),
            ),
            const SizedBox(height: 24),
            Text(
              'أهلاً يا ${child.name}! 👋',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'جاهز نروح نلعب؟',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
            const Spacer(),
            BigButton(
              label: 'يلا نلعب',
              emoji: '🎮',
              color: AppColors.green,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MainMenuScreen(childId: childId),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WeakPointsScreen(childId: childId),
                ),
              ),
              child: const Text(
                'نقاط ضعف الطفل (للوالدين)',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
