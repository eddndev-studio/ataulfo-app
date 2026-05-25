import 'package:flutter/material.dart';

import '../tokens.dart';

/// Avatar circular del design system: circle surface3 con la inicial
/// uppercase del nombre. Es el reemplazo del [CircleAvatar] de Material,
/// que arrastra el tinte primary del theme y un radius de 20 implícito.
///
/// `size` parametriza diámetro total — los listados usan 40 (densidad
/// alta) y los detalles 64 (header). El font-size del label sigue siendo
/// bodyL fijo: en tamaños mayores la inicial queda relativamente más
/// pequeña, lo cual es deliberado para no pelear con el título adyacente.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTokens.surface3,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initial(name),
        style: const TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: AppTokens.bodyLSize,
          fontWeight: FontWeight.w600,
          color: AppTokens.text1,
        ),
      ),
    );
  }

  static String _initial(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}
