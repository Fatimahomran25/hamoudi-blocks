import 'package:flutter/material.dart';

import '../../models/content_item.dart';
import '../../theme/app_theme.dart';
import 'language_select_screen.dart';

/// القائمة الرئيسية: 🔤 الحروف / 🔢 الأرقام.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('وش نتعلم اليوم؟')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: _MenuCard(
                  emoji: '🔤',
                  label: 'الحروف',
                  color: AppColors.blue,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LanguageSelectScreen(
                        childId: childId,
                        isLetters: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _MenuCard(
                  emoji: '🔢',
                  label: 'الأرقام',
                  color: AppColors.orange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LanguageSelectScreen(
                        childId: childId,
                        isLetters: false,
                      ),
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

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeoBox(
        color: color,
        borderRadius: 28,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يحدد المجموعات الأربع من (حروف/أرقام) × (عربي/إنجليزي).
ContentGroup groupFor({required bool isLetters, required bool isArabic}) {
  if (isLetters) {
    return isArabic ? ContentGroup.arabicLetters : ContentGroup.englishLetters;
  }
  return isArabic ? ContentGroup.arabicNumbers : ContentGroup.englishNumbers;
}
