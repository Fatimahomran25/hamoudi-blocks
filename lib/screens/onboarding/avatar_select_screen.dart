import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/avatar_option.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../../widgets/blocky_avatar.dart';
import '../home/game_login_screen.dart';

/// Picking the child's character from 4-6 ready-made options, with a live
/// animated preview. Shown the first time right after adding the child,
/// and also reachable later from settings.
class AvatarSelectScreen extends StatefulWidget {
  const AvatarSelectScreen({super.key, required this.childName});

  final String childName;

  @override
  State<AvatarSelectScreen> createState() => _AvatarSelectScreenState();
}

class _AvatarSelectScreenState extends State<AvatarSelectScreen> {
  String _selectedId = kAvatarOptions.first.id;
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final profileService = context.read<ProfileService>();
    final child = await profileService.addChild(
      name: widget.childName,
      avatarId: _selectedId,
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => GameLoginScreen(childId: child.id)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = avatarById(_selectedId);
    return Scaffold(
      appBar: AppBar(title: const Text('اختر شخصيتك يا بطل')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            NeoBox(
              color: selected.jacketColor.withValues(alpha: 0.18),
              child: SizedBox(
                height: 150,
                child: Center(
                  child: BlockyAvatarPreview(avatar: selected, scale: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: kAvatarOptions.length,
                itemBuilder: (context, index) {
                  final option = kAvatarOptions[index];
                  final isSelected = option.id == _selectedId;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedId = option.id),
                    child: NeoBox(
                      color: isSelected ? AppColors.surfaceLight : AppColors.surface,
                      borderColor: isSelected ? AppColors.yellow : AppColors.ink,
                      borderWidth: isSelected ? 4 : 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BlockyAvatarPreview(avatar: option, animate: isSelected),
                          const SizedBox(height: 6),
                          Text(
                            option.name,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: BigButton(
                label: _saving ? '...' : 'ابدأ اللعب',
                emoji: '🎮',
                color: AppColors.green,
                onPressed: _saving ? null : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
