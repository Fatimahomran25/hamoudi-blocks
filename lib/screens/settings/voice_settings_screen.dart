import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

/// Voice settings. Per the "audio quality" section of the original prompt,
/// the chosen approach is pre-recorded audio (not live TTS, see
/// lib/services/audio_service.dart) — this screen is just a general sound
/// on/off toggle, there's no "device voice" picker.
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
