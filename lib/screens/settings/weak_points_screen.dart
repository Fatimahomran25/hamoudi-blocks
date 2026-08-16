import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/content_item.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';

/// The "Child's Weak Points" screen (parents only, reached via a button in
/// GameLoginScreen). Two steps: 1) pick a group (letters/numbers x Arabic/
/// English) 2) a grid of that group's items — tap any item to mark/unmark
/// it as a weak point. Marked items are automatically added as bonus rounds
/// at the end of every future level in the same group (see
/// GameScreen._buildRoundItems) until unmarked.
class WeakPointsScreen extends StatefulWidget {
  const WeakPointsScreen({super.key, required this.childId});

  final String childId;

  @override
  State<WeakPointsScreen> createState() => _WeakPointsScreenState();
}

class _WeakPointsScreenState extends State<WeakPointsScreen> {
  ContentGroup? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final group = _selectedGroup;
    return Scaffold(
      appBar: AppBar(
        title: Text(group == null ? 'نقاط ضعف الطفل' : '${group.flagEmoji} ${group.titleAr}'),
        leading: group == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => setState(() => _selectedGroup = null),
              ),
      ),
      body: SafeArea(
        child: group == null ? _buildGroupPicker(context) : _buildItemGrid(context, group),
      ),
    );
  }

  Widget _buildGroupPicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'اختاري القسم اللي تبين تحدّدين فيه نقاط ضعف حمودي',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: ContentGroup.values
                  .map((g) => GestureDetector(
                        onTap: () => setState(() => _selectedGroup = g),
                        child: NeoBox(
                          color: AppColors.surface,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(g.flagEmoji, style: const TextStyle(fontSize: 34)),
                              const SizedBox(height: 8),
                              Text(
                                g.titleAr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(BuildContext context, ContentGroup group) {
    final profileService = context.watch<ProfileService>();
    final child = profileService.children.firstWhere((c) => c.id == widget.childId);
    final items = ContentRepository.forGroup(group);
    final weakCount = child.weakSymbolsFor(group).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            weakCount == 0
                ? 'اضغطي على أي عنصر تحسّينه نقطة ضعف — بينضاف كجولة إضافية بآخر كل مستوى قادم لحد ما تشيلينه.'
                : 'محدّدة $weakCount كنقطة ضعف حالياً — بتتكرر بآخر كل مستوى قادم بهالقسم.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final isWeak = child.isWeakItem(group, item.symbol);
              return GestureDetector(
                onTap: () => context.read<ProfileService>().setWeakItem(
                      childId: widget.childId,
                      group: group,
                      symbol: item.symbol,
                      isWeak: !isWeak,
                    ),
                child: NeoBox(
                  color: isWeak ? AppColors.red.withValues(alpha: 0.25) : AppColors.surface,
                  borderColor: isWeak ? AppColors.red : AppColors.ink,
                  borderWidth: isWeak ? 3 : 2,
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.symbol,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textLight)),
                      Text(item.emoji, style: const TextStyle(fontSize: 16)),
                      if (isWeak) const Icon(Icons.favorite, color: AppColors.red, size: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'عند الضغط، تُقفَل كل مستويات هذا القسم من جديد',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: BigButton(
            label: 'إعادة تعيين تقدّم القسم',
            emoji: '♻️',
            color: AppColors.surfaceLight,
            onPressed: () => _confirmReset(context, group),
          ),
        ),
      ],
    );
  }

  void _confirmReset(BuildContext context, ContentGroup group) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تأكيد إعادة التعيين', style: TextStyle(color: AppColors.textLight)),
        content: Text(
          'سيُصفَّر كل تقدّم "${group.titleAr}" (النجوم والمستويات المفتوحة) — دون مسح نقاط الضعف المحدَّدة. هل أنتِ متأكدة؟',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProfileService>().resetGroupProgress(childId: widget.childId, group: group);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('تأكيد إعادة التعيين', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
