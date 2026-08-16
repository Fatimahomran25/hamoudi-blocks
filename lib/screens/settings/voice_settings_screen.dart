import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

/// إعدادات الصوت. بحسب قسم "جودة الصوت" بالبرومت الأصلي، القرار المعتمد
/// هو أصوات مسجّلة مسبقاً (مو TTS حي، راجعي lib/services/audio_service.dart)
/// — فقط تشغيل/إيقاف الصوت بشكل عام هنا، ما فيه اختيار "صوت الجهاز".
class VoiceSettingsScreen extends StatelessWidget {
  const VoiceSettingsScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final child = profileService.children.firstWhere((c) => c.id == childId);

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الصوت')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeoBox(
                child: SwitchListTile(
                  value: child.soundEnabled,
                  activeThumbColor: AppColors.green,
                  title: const Text('تشغيل الأصوات', style: TextStyle(color: AppColors.textLight)),
                  subtitle: const Text(
                    'تشجيع، تلميحات، مؤثرات الحركة',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  onChanged: (value) =>
                      context.read<ProfileService>().setSoundEnabled(childId, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
