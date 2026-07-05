import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Contrato del kit para resolver los bytes de la miniatura de un `mediaRef`
/// BARE. La app inyecta la implementación (típicamente el cache de miniaturas
/// de la galería); el kit no conoce redes, discos ni el catálogo de media.
/// `null` ⇒ no hay miniatura disponible y el widget cae al glifo por tipo.
///
/// La miniatura es EFÍMERA por diseño: lo único que identifica al recurso —y
/// lo único que se persiste— es el `mediaRef` BARE. Cualquier URL firmada que
/// la implementación use para obtener los bytes vive y muere dentro de ella.
typedef AppMediaThumbLoader = Future<Uint8List?> Function(String mediaRef);

/// Familia visual del recurso, para el glifo de respaldo cuando no hay bytes
/// que pintar (miniatura aún no derivada, cache frío o tipo sin imagen).
enum AppMediaKind { image, video, audio, document }

/// Glifo de respaldo por familia. La identidad visual del tipo es la misma en
/// cualquier superficie que caiga al fallback.
IconData appMediaKindIcon(AppMediaKind kind) => switch (kind) {
  AppMediaKind.image => Icons.image_outlined,
  AppMediaKind.video => Icons.movie_outlined,
  AppMediaKind.audio => Icons.audiotrack_outlined,
  AppMediaKind.document => Icons.insert_drive_file_outlined,
};

/// Miniatura cuadrada y efímera de un recurso multimedia identificado por su
/// `mediaRef` BARE.
///
/// Tres estados, siempre del mismo tamaño para no saltar el layout:
/// - resolviendo ⇒ placeholder QUIETO (sin spinner: es un adorno del form, no
///   una operación que el usuario espere);
/// - sin bytes o bytes corruptos ⇒ glifo por [kind] — fallback honesto: la
///   miniatura es opcional, el recurso sigue identificado por su ref;
/// - bytes válidos ⇒ imagen con `fit: cover` recortada a los radios del kit.
///
/// Re-resuelve cuando cambia [mediaRef]. La identidad del [loader] NO dispara
/// re-resolución (los call-sites suelen pasar closures nuevas por build); si la
/// FUENTE de bytes mejora para el mismo ref (p. ej. aparece el asset con URL),
/// el caller fuerza el remount con una [Key] distinta.
class AppMediaThumb extends StatefulWidget {
  const AppMediaThumb({
    super.key,
    required this.mediaRef,
    required this.loader,
    required this.kind,
    this.size = 48,
  });

  /// Identificador BARE del recurso. Es la ÚNICA identidad; nunca una URL.
  final String mediaRef;

  final AppMediaThumbLoader loader;

  /// Familia del recurso para el glifo de respaldo.
  final AppMediaKind kind;

  /// Lado del cuadrado, en dp.
  final double size;

  @override
  State<AppMediaThumb> createState() => _AppMediaThumbState();
}

class _AppMediaThumbState extends State<AppMediaThumb> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.loader(widget.mediaRef);
  }

  @override
  void didUpdateWidget(AppMediaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaRef != widget.mediaRef) {
      _bytes = widget.loader(widget.mediaRef);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusChip);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: radius,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ColoredBox(
                key: ValueKey('app_media_thumb.loading'),
                color: AppTokens.surface2,
              );
            }
            final bytes = snapshot.data;
            if (bytes == null) return _fallback();
            return Image.memory(
              bytes,
              key: const ValueKey('app_media_thumb.image'),
              fit: BoxFit.cover,
              // Bytes que no decodifican (corruptos o no-imagen): el mismo
              // glifo de respaldo, nunca el ícono roto de Flutter.
              errorBuilder: (_, _, _) => _fallback(),
            );
          },
        ),
      ),
    );
  }

  /// Glifo por tipo sobre la superficie del kit. El tamaño del ícono escala
  /// con el lado, acotado para no verse ni perdido ni desbordado.
  Widget _fallback() => ColoredBox(
    key: const ValueKey('app_media_thumb.fallback'),
    color: AppTokens.surface2,
    child: Center(
      child: Icon(
        appMediaKindIcon(widget.kind),
        color: AppTokens.text2,
        size: (widget.size * 0.5).clamp(16.0, 28.0),
      ),
    ),
  );
}
