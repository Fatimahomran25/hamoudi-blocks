import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/big_button.dart';
import '../onboarding/add_child_screen.dart';

/// شاشة حساب الوالد لمرة وحدة: إنشاء حساب أو تسجيل دخول (إيميل/باسورد).
/// هذي الشاشة الوحيدة اللي يستخدمها الوالد مباشرة — الطفل ما يشوفها أبداً
/// بعد الإعداد الأول (الجلسة تُتذكّر تلقائياً).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreateMode = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final auth = context.read<AuthService>();
    final error = _isCreateMode
        ? await auth.createAccount(_emailController.text, _passwordController.text)
        : await auth.signIn(_emailController.text, _passwordController.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
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
                    const Text('🧊', style: TextStyle(fontSize: 64), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'بلوك حمودي',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCreateMode ? 'إنشاء حساب الوالد (مرة وحدة فقط)' : 'تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
                    const SizedBox(height: 28),
                    NeoBox(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppColors.textLight),
                            decoration: const InputDecoration(
                              labelText: 'الإيميل',
                              border: InputBorder.none,
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? 'اكتبي إيميل صحيح' : null,
                          ),
                          const Divider(color: AppColors.surfaceLight),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: AppColors.textLight),
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              border: InputBorder.none,
                            ),
                            validator: (v) =>
                                (v == null || v.length < 4) ? 'على الأقل 4 حروف/أرقام' : null,
                          ),
                        ],
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorText!, style: const TextStyle(color: AppColors.red)),
                    ],
                    const SizedBox(height: 20),
                    BigButton(
                      label: _submitting
                          ? '...'
                          : (_isCreateMode ? 'إنشاء الحساب' : 'دخول'),
                      color: AppColors.blue,
                      onPressed: _submitting ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        _isCreateMode = !_isCreateMode;
                        _errorText = null;
                      }),
                      child: Text(
                        _isCreateMode ? 'عندي حساب، تسجيل الدخول' : 'حساب جديد؟ إنشاء حساب',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
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
