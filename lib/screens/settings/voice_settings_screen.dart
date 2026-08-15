import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

/// إعدادات الصوت. بحسب قسم "جودة الصوت" بالبرومت الأصلي، القرار المعتمد
/// هو أصوات مسجّلة مسبقاً (مو TTS حي)، فما فيه هنا اختيار "صوت الجهاز"
/// — فقط تشغيل/إيقاف الصوت بشكل عام لحد ما تُضاف المقاطع الفعلية
/// بـ Milestone 3.
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
              const SizedBox(height: 16),
              const NeoBox(
                color: AppColors.surfaceLight,
                child: Text(
                  '🚧 قريباً: أصوات عربية طبيعية مسجّلة مسبقاً لكل حرف ورقم وعبارة '
                  'تشجيع (بدل صوت الجهاز الروبوتي) — راجعي قسم "جودة الصوت" بخطة '
                  'المشروع لتفاصيل التوليد.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
