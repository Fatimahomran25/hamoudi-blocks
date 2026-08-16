import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home/game_login_screen.dart';
import 'screens/onboarding/add_child_screen.dart';
import 'screens/onboarding/sign_in_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'theme/app_theme.dart';

class HamoudiBlocksApp extends StatelessWidget {
  const HamoudiBlocksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..loadSession()),
        ChangeNotifierProvider(create: (_) => ProfileService()..load()),
      ],
      child: MaterialApp(
        title: 'بلوك حمودي',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decides the first screen the user sees based on the locally saved
/// session state: no account → sign in/create account. An account with no
/// children → add a child. An account with children → straight into the
/// game (the child doesn't type anything).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profiles = context.watch<ProfileService>();

    if (!auth.isLoaded || !profiles.isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text('🧊', style: TextStyle(fontSize: 64)),
        ),
      );
    }

    if (!auth.isSignedIn) return const SignInScreen();
    if (profiles.children.isEmpty) return const AddChildScreen();

    final active = profiles.activeChild ?? profiles.children.first;
    return GameLoginScreen(childId: active.id);
  }
}
