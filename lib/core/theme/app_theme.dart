import 'package:flutter/material.dart';

/// Tema visual del cliente.
///
/// Seed inspirada en el azul de Telegram (`#2AABEE`); Material 3 genera el
/// resto de la paleta dinámica. Tipografía default (Roboto en Android) —
/// cambiar a una custom (Inter, etc.) se decide cuando un slice de diseño
/// lo pida.
class AppTheme {
  const AppTheme._();

  static const Color seed = Color(0xFF2AABEE);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
