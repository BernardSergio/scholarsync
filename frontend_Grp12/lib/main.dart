// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';

void main() {
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFEEEEEE)),
          ),
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        // ✅ Handle reset password deep link
          if ((settings.name ?? '').startsWith('/reset-password')) {
            String token = '';

            if (kIsWeb) {
              // Extract token from fragment for web hash URLs
              final fragment = Uri.base.fragment; // e.g., "/reset-password?token=abcd1234"
              final uri = Uri.parse(fragment.replaceFirst('#', '')); // remove # if any
              token = uri.queryParameters['token'] ?? '';
            } else if (settings.arguments is String) {
              token = settings.arguments as String;
            }

            return MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(resetToken: token),
            );
          }

        // ✅ Default routes
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}
