import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بوابة حساب الوالد (إيميل/باسورد) — إعداد لمرة وحدة.
///
/// ⚠️ Milestone 1 فقط: التخزين محلي 100% على الجهاز (SharedPreferences)،
/// بدون أي شبكة أو خادم. هذا يكفي تماماً بمرحلة الهيكلة الحالية، لكنه
/// *ليس* بديل أمان حقيقي — بـ Milestone 4 يُستبدل الجسم الداخلي لهالكلاس
/// بـ firebase_auth (نفس الواجهة العامة signIn/createAccount/signOut
/// تبقى كما هي، فباقي الشاشات ما تتغيّر).
class AuthService extends ChangeNotifier {
  static const _kEmailKey = 'parent_email';
  static const _kPasswordKey = 'parent_password';

  String? _email;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isSignedIn => _email != null;
  String? get parentEmail => _email;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(_kEmailKey);
    _loaded = true;
    notifyListeners();
  }

  Future<bool> hasAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kEmailKey);
  }

  Future<String?> createAccount(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kEmailKey)) {
      return 'فيه حساب موجود على هذا الجهاز، جرّبي تسجيل الدخول بدل إنشاء حساب جديد.';
    }
    await prefs.setString(_kEmailKey, email.trim());
    await prefs.setString(_kPasswordKey, password);
    _email = email.trim();
    notifyListeners();
    return null; // null = نجاح
  }

  Future<String?> signIn(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_kEmailKey);
    final savedPassword = prefs.getString(_kPasswordKey);
    if (savedEmail == null || savedEmail.trim() != email.trim() || savedPassword != password) {
      return 'الإيميل أو كلمة المرور غير صحيحة.';
    }
    _email = savedEmail;
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    _email = null;
    notifyListeners();
    // ملاحظة: ما نمسح بيانات الحساب من التخزين (عشان ما نفقد بروفايلات
    // الأطفال)، فقط ننهي الجلسة الحالية بالواجهة.
  }
}
