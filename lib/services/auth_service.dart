import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The parent account gate (email/password) — a one-time setup.
///
/// ⚠️ Milestone 1 only: storage is 100% local on the device
/// (SharedPreferences), with no network or server. This is entirely enough
/// for the current scaffolding stage, but it is *not* a real security
/// substitute — in Milestone 4 this class's internals get replaced with
/// firebase_auth (the same public signIn/createAccount/signOut interface
/// stays as-is, so the rest of the screens don't change).
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
    return null; // null = success
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
    // Note: we don't clear the account data from storage (so we don't lose
    // the children's profiles), we just end the current UI session.
  }
}
