import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../bloc/media_detail_cubit.dart';
import '../media_format.dart';

/// Detalle de un asset de la galería: previsualización + metadata + copiar la
/// referencia BARE + borrar. Cubit-driven: el [MediaDetailCubit] (inyectado por
/// la ruta con el asset abierto) es la verdad mostrada, así una mutación (borrar;
/// renombrar se añade aparte) refleja sin recargar. Al borrar con éxito la
/// página hace pop devolviendo `true` para que la galería se refresque.
///
/// La previsualización de imagen reusa el [MediaThumbnailLoader] (no hay
/// resolución "full" separada: los mismos bytes que la miniatura son la imagen
/// completa) dentro de un [InteractiveViewer]. Video/audio/documento muestran el
/// ícono del tipo. La `previewUrl` efímera NO es identidad; esa es
/// [MediaAsset.ref].
class MediaDetailPage extends StatelessWidget {
  const MediaDetailPage({super.key, required this.loader});

  final MediaThumbnailLoader loader;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MediaDetailCubit, MediaDetailState>(
      listenWhen: (prev, curr) =>
          prev.deleted != curr.deleted || prev.error != curr.error,
      listener: (context, state) {
        if (state.deleted) {
          Navigator.of(context).pop(true);
          return;
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('No pudimos borrar el archivo')),
            );
        }
      },
      builder: (context, state) {
        final asset = state.asset;
        return Scaffold(
          appBar: AppBar(
            title: Text(asset.displayName, overflow: TextOverflow.ellipsis),
            actions: <Widget>[
              IconButton(
                key: const Key('media_detail.delete'),
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline),
                color: AppTokens.danger,
                onPressed: state.busy ? null : () => _confirmDelete(context),
              ),
            ],
          ),
          body: Stack(
            children: <Widget>[
              ListView(
                padding: const EdgeInsets.all(AppTokens.sp4),
                children: <Widget>[
                  _Preview(asset: asset, loader: loader),
                  const SizedBox(height: AppTokens.sp5),
                  _MetadataCard(asset: asset),
                ],
              ),
              if (state.busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTokens.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Confirma antes de borrar (acción irreversible) y delega al cubit.
  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<MediaDetailCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar archivo'),
        content: const Text(
          'Se quitará de la galería y de cualquier flujo que lo use. Esta '
          'acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.deleteAsset();
  }
}

/// Área de previsualización: imagen con zoom/pan, o el ícono del tipo para lo
/// no renderizable. Carga los bytes una sola vez (StatefulWidget) para no
/// re-pedirlos en cada rebuild.
class _Preview extends StatefulWidget {
  const _Preview({required this.asset, required this.loader});

  final MediaAsset asset;
  final MediaThumbnailLoader loader;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final Future<Uint8List?> _bytes = widget.loader.load(widget.asset);

  bool get _isImage => widget.asset.contentType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    // Altura acotada (no AspectRatio a ancho completo, que en pantallas altas
    // empujaría la metadata fuera de vista): un visor contenido deja ver el
    // archivo y la metadata juntos. El zoom del InteractiveViewer cubre el
    // detalle fino de las imágenes.
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Container(
          color: AppTokens.surface2,
          alignment: Alignment.center,
          child: _isImage ? _image() : _typeIcon(),
        ),
      ),
    );
  }

  Widget _image() => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.text2),
        );
      }
      final bytes = snapshot.data;
      if (bytes == null) return _typeIcon();
      return InteractiveViewer(
        maxScale: 5,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _typeIcon(),
        ),
      );
    },
  );

  Widget _typeIcon() => Icon(
    _iconFor(widget.asset.contentType),
    color: AppTokens.text2,
    size: 64,
  );

  static IconData _iconFor(String contentType) {
    if (contentType.startsWith('image/')) return Icons.image_outlined;
    if (contentType.startsWith('video/')) return Icons.movie_outlined;
    if (contentType.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (contentType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

/// Tarjeta de metadata: nombre, alias (si hay), tipo, tamaño, fecha y el ref
/// con botón de copiar. El ref es lo que se persiste en flujos, así que copiarlo
/// es de primera clase.
class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp4),
      decoration: BoxDecoration(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row('Nombre', asset.filename),
          if (asset.alias.isNotEmpty) _row('Alias', asset.alias),
          _row('Tipo', asset.contentType),
          _row('Tamaño', formatBytes(asset.size)),
          _row('Subido', formatDate(asset.createdAt.toLocal())),
          const Divider(height: AppTokens.sp6, color: AppTokens.surface3),
          _RefRow(ref: asset.ref),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(color: AppTokens.text2, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppTokens.text1, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// Fila del ref con botón de copiar. Copia el ref BARE (identidad permanente)
/// al portapapeles y confirma con un snackbar.
class _RefRow extends StatelessWidget {
  const _RefRow({required this.ref});

  final String ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(
          width: 88,
          child: Text(
            'Referencia',
            style: TextStyle(color: AppTokens.text2, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            ref,
            style: const TextStyle(
              color: AppTokens.text2,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          key: const Key('media_detail.copy_ref'),
          tooltip: 'Copiar referencia',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_outlined, size: 18),
          color: AppTokens.text1,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: ref));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Referencia copiada')),
              );
          },
        ),
      ],
    );
  }
}
