import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/avatar_option.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../../widgets/blocky_avatar.dart';
import '../settings/voice_settings_screen.dart';
import 'main_menu_screen.dart';

/// شاشة "دخول اللعبة": هذي أول شي يشوفه الطفل عند فتح التطبيق بعد أول
/// إعداد — بروفايله جاهز (اسمه + شخصيته)، بدون ما يكتب أو يقرأ أي شي.
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.textMuted, size: 30),
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
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
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
                  MaterialPageRoute(builder: (_) => MainMenuScreen(childId: childId)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _confirmSwitchChild(context),
                child: const Text(
                  'تبديل الطفل (للوالدين)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSwitchChild(BuildContext context) {
    // TODO(milestone-4): بوابة والدين حقيقية (سؤال حسابي بسيط) بدل تأكيد
    // مباشر، عشان الطفل ما يقدر يخرج من بروفايله بالغلط.
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تبديل الطفل', style: TextStyle(color: AppColors.textLight)),
        content: const Text(
          'هذي الميزة (إدارة أكثر من طفل بنفس الحساب) جاهزة بالبروفايل، وسيُضاف لها '
          'اختيار من قائمة الأطفال + بوابة والدين قبل الإطلاق الكامل.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
