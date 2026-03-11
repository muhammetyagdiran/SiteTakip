import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:site_takip/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'package:site_takip/l10n/app_localizations.dart';
import 'screens/auth/login_screen.dart';
import 'screens/web/web_login_screen.dart';
import 'screens/web/web_owner_dashboard.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/resident/resident_dashboard.dart';
import 'models/user_model.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  await SupabaseService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'Site Takip',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.isModern ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('tr'),
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      // Sadece uygulama ilk açıldığında profil bekleniyorsa yükleme ekranı göster
      // Giriş yaparken LoginScreen içindeki yükleme göstergesi yeterli
      if (authService.isLoading && authService.currentUser == null && !authService.isLoggingIn) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      
      // Route to Web Login on large screens
      if (kIsWeb && MediaQuery.of(context).size.width > 800) {
        return const WebLoginScreen();
      }
      
      return const LoginScreen();
    }

    switch (user.role) {
      case UserRole.systemOwner:
        if (kIsWeb && MediaQuery.of(context).size.width > 800) {
          return const WebOwnerDashboard();
        }
        return const OwnerDashboard();
      case UserRole.siteManager:
        return const ManagerDashboard();
      case UserRole.resident:
        return const ResidentDashboard();
    }
  }
}
