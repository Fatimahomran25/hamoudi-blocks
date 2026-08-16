import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'levels_screen.dart';
import 'main_menu_screen.dart';

/// Language selection: 🇸🇦 Arabic / 🇬🇧 English.
class LanguageSelectScreen extends StatelessWidget {
  const LanguageSelectScreen({
    super.key,
    required this.childId,
    required this.isLetters,
  });

  final String childId;
  final bool isLetters;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLetters ? '🔤 الحروف' : '🔢 الأرقام')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: _LangCard(
                  flag: '🇸🇦',
                  label: 'عربي',
                  color: AppColors.green,
                  onTap: () => _openLevels(context, isArabic: true),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _LangCard(
                  flag: '🇬🇧',
                  label: 'English',
                  color: AppColors.purple,
                  onTap: () => _openLevels(context, isArabic: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLevels(BuildContext context, {required bool isArabic}) {
    final group = groupFor(isLetters: isLetters, isArabic: isArabic);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelsScreen(childId: childId, group: group),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.flag,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String flag;
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
              Text(flag, style: const TextStyle(fontSize: 72)),
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
