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
/// alta) y los detalles 64 (header). El font-size del label escala con el
/// diámetro (`size * 0.4`) para que la inicial guarde la misma proporción en
/// cualquier tamaño, como muestra el kit.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrl,
  });

  final String name;
  final double size;

  /// Foto opcional (URL firmada/efímera). Si viene, se carga recortada en el
  /// círculo con el anillo de marca; al fallar o no estar (`null`) cae a la
  /// inicial. Mantiene la misma forma y semántica que la variante de iniciales.
  final String? imageUrl;

  /// Grosor del anillo de marca. Fijo en cualquier tamaño: un borde más
  /// delgado se perdería en avatares chicos y uno proporcional al diámetro
  /// engordaría de más en el header.
  static const double _ringWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    // El lector de pantalla anuncia el nombre completo, no la inicial suelta:
    // excludeSemantics suprime el nodo de la letra para que solo se oiga `name`.
    Widget label() => Text(
      _initial(name),
      style: TextStyle(
        fontFamily: AppTokens.fontSans,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w600,
        color: AppTokens.text1,
      ),
    );
    final url = imageUrl;
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTokens.surface3,
          shape: BoxShape.circle,
          border: Border.all(color: AppTokens.primary, width: _ringWidth),
        ),
        alignment: Alignment.center,
        clipBehavior: url == null ? Clip.none : Clip.antiAlias,
        child: url == null
            ? label()
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Foto rota / R2 caído / aún cargando ⇒ la inicial.
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: label()),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : Center(child: label()),
              ),
      ),
    );
  }

  static String _initial(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    // Primer cluster de grafemas, no `substring(0, 1)`: respeta emojis y
    // pares surrogate que un corte por code unit partiría a la mitad.
    return trimmed.characters.first.toUpperCase();
  }
}
