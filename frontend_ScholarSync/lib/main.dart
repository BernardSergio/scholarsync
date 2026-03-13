import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'forgot_passphrase_screen.dart';
import 'reset_password_screen.dart';

void main() {
  runApp(const ScholarSyncApp());
}

class ScholarSyncApp extends StatelessWidget {
  const ScholarSyncApp({super.key});

  // ── ScholarSync Design Tokens ──────────────────────────────
  static const Color primary        = Color(0xFFFFC107); // Amber
  static const Color background     = Color(0xFFF5F5F5); // Light grey
  static const Color surface        = Color(0xFFFFFFFF); // White cards
  static const Color foreground     = Color(0xFF1A1A1A); // Near black text
  static const Color muted          = Color(0xFFE8E8E8); // Muted bg
  static const Color mutedForeground= Color(0xFF5A5A4D); // Muted text
  static const Color destructive    = Color(0xFFD4183D); // Error red
  static const Color border         = Color(0xFFE0E0E0); // Borders
  // ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScholarSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.light(
          primary: primary,
          onPrimary: foreground,
          secondary: primary,
          onSecondary: foreground,
          surface: surface,
          onSurface: foreground,
          error: destructive,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: foreground,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: muted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/forgot-passphrase': (context) => const ForgotPassphraseScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/reset-password')) {
          final uri = Uri.parse(settings.name!);
          final token = uri.queryParameters['token'] ?? '';
          return MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(resetToken: token),
          );
        }
        return null;
      },
    );
  }
}