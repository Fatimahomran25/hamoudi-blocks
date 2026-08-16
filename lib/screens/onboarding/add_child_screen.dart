import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import 'avatar_select_screen.dart';

/// The "add a child" screen: just the child's name (the parent types it),
/// then character selection.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarSelectScreen(childName: _controller.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('👶', style: TextStyle(fontSize: 64), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'شو اسم بطلنا؟',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 24),
                    NeoBox(
                      child: TextFormField(
                        controller: _controller,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textLight, fontSize: 22),
                        decoration: const InputDecoration(
                          hintText: 'مثلاً: حمودي',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'اكتبي اسم الطفل' : null,
                        onFieldSubmitted: (_) => _next(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    BigButton(label: 'التالي', emoji: '➡️', color: AppColors.blue, onPressed: _next),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
