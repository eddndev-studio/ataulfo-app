import 'package:flutter/material.dart';

import '../tokens.dart';

/// Avatar circular del design system: círculo con un anillo perimetral
/// [AppTokens.primary], relleno en superficie oscura del kit y la inicial
/// uppercase del nombre. Es el reemplazo del [CircleAvatar] de Material,
/// que arrastra el tinte primary del theme y un radius de 20 implícito.
///
/// El anillo amarillo es el protagonista del re-skin (patrón UserIcon del
/// kit); el relleno se mantiene en una superficie oscura ([AppTokens.surface3])
/// para que la inicial y el borde resalten contra el fondo.
///
/// `size` parametriza diámetro total — los listados usan 40 (densidad
/// alta) y los detalles 64 (header). El font-size del label sigue siendo
/// bodyL fijo: en tamaños mayores la inicial queda relativamente más
/// pequeña, lo cual es deliberado para no pelear con el título adyacente.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  /// Grosor del anillo de marca. Fijo en cualquier tamaño: un borde más
  /// delgado se perdería en avatares chicos y uno proporcional al diámetro
  /// engordaría de más en el header.
  static const double _ringWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTokens.surface3,
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.primary, width: _ringWidth),
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
