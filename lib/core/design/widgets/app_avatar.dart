import 'package:flutter/material.dart';

import '../tokens.dart';

/// Avatar circular del design system: círculo plano sin borde, con la foto
/// recortada a círculo completo o, en su defecto, la inicial uppercase del
/// nombre sobre un relleno oscuro. Es el reemplazo del [CircleAvatar] de
/// Material, que arrastra el tinte primary del theme y un radius de 20
/// implícito.
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
    this.imageProvider,
    this.colorKey,
  });

  final String name;
  final double size;

  /// Clave estable del contacto para derivar el color de fondo del fallback sin
  /// foto (un id de servidor: chatLid, email, org id…). El mismo valor produce
  /// siempre el mismo color en cualquier pantalla y dispositivo. Si es `null`,
  /// se usa [name] como último recurso, que pierde estabilidad si el nombre
  /// cambia en runtime (p. ej. de un placeholder al nombre real).
  final String? colorKey;

  /// Foto opcional (URL firmada/efímera). Si viene, se recorta al círculo
  /// completo; al fallar o no estar (`null`) cae a la inicial. Mantiene la misma
  /// forma y semántica que la variante de iniciales.
  final String? imageUrl;

  /// Fuente de imagen local opcional (p. ej. `MemoryImage` de la caché de fotos
  /// en disco). Se usa cuando no hay [imageUrl]; permite servir la foto cacheada
  /// sin depender de una URL viva. Mismo recorte al círculo y caída a la inicial.
  final ImageProvider? imageProvider;

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
    final fillColor =
        AppTokens.avatarFallbackPalette[_paletteIndex(colorKey ?? name)];
    final dim = size;
    // La foto ocupa el círculo completo y se recorta con ClipOval.
    Widget framed(Widget img) => ClipOval(child: img);
    Widget content;
    if (url != null) {
      content = framed(
        Image.network(
          url,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          // Foto rota / R2 caído / aún cargando ⇒ la inicial.
          errorBuilder: (context, error, stackTrace) => Center(child: label()),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Center(child: label()),
        ),
      );
    } else if (imageProvider != null) {
      content = framed(
        Image(
          image: imageProvider!,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(child: label()),
          frameBuilder: (context, child, frame, wasSync) =>
              (frame == null && !wasSync) ? Center(child: label()) : child,
        ),
      );
    } else {
      content = label();
    }
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: fillColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        child: content,
      ),
    );
  }

  /// Índice determinista en [AppTokens.avatarFallbackPalette] derivado de una
  /// clave estable. Usa FNV-1a (no `String.hashCode`, que está sembrado por
  /// ejecución y no sería estable entre runs ni dispositivos).
  static int _paletteIndex(String key) =>
      _fnv1a(key) % AppTokens.avatarFallbackPalette.length;

  /// FNV-1a de 32 bits sobre los runes de [s]. Determinista y portable.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (final r in s.runes) {
      hash = ((hash ^ r) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static String _initial(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '?';
    // Primer cluster de grafemas, no `substring(0, 1)`: respeta emojis y
    // pares surrogate que un corte por code unit partiría a la mitad.
    return trimmed.characters.first.toUpperCase();
  }
}
