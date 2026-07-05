import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/copy_text_actions.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_preview_launcher.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../bloc/media_detail_cubit.dart';
import '../media_format.dart';
import '../widgets/alias_edit_sheet.dart';

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
  const MediaDetailPage({
    super.key,
    required this.loader,
    required this.launcher,
  });

  final MediaThumbnailLoader loader;

  /// Abre en el visor del sistema lo que no se renderiza inline (video, audio,
  /// documentos). La imagen se previsualiza inline; el resto delega aquí.
  final MediaPreviewLauncher launcher;

  @override
  Widget build(BuildContext context) {
    // PopScope FUERA del BlocConsumer: la galería se refresca al volver sólo si
    // hubo cambio (renombrado). canPop:false ⇒ el back del AppBar/sistema entra
    // por el handler y hace pop con el flag (leído on-demand, sin que el consumer
    // rebuilds durante el pop toque un cubit ya dispuesto). El borrado hace
    // pop(true) aparte desde el listener.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final changed = context.read<MediaDetailCubit>().state.changed;
        Navigator.of(context).pop(changed);
      },
      child: BlocConsumer<MediaDetailCubit, MediaDetailState>(
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
                const SnackBar(content: Text('No pudimos completar la acción')),
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
                  key: const Key('media_detail.edit_alias'),
                  tooltip: 'Renombrar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: state.busy ? null : () => _editAlias(context),
                ),
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
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.sp4,
                    AppTokens.sp4,
                    AppTokens.sp4,
                    AppTokens.sp4 + context.safeBottomInset,
                  ),
                  children: <Widget>[
                    _Preview(asset: asset, loader: loader),
                    if (_canOpenExternally(asset)) ...<Widget>[
                      const SizedBox(height: AppTokens.sp4),
                      _openButton(context, asset),
                    ],
                    const SizedBox(height: AppTokens.sp5),
                    _MetadataCard(asset: asset),
                  ],
                ),
                if (state.busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: AppTokens.scrim,
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
      ),
    );
  }

  /// Abre el form-sheet de renombrar (prefijado con el alias actual) y delega
  /// al cubit. Un alias vacío limpia el nombre amistoso (vuelve al filename).
  Future<void> _editAlias(BuildContext context) async {
    final cubit = context.read<MediaDetailCubit>();
    final result = await AliasEditSheet.open(
      context,
      initial: cubit.state.asset.alias,
    );
    if (result != null) await cubit.setAlias(result);
  }

  /// Se puede abrir en el visor del sistema lo NO renderizado inline (no imagen)
  /// que tenga una URL de preview firmada.
  bool _canOpenExternally(MediaAsset asset) =>
      !asset.contentType.startsWith('image/') &&
      (asset.previewUrl?.isNotEmpty ?? false);

  /// Botón de previsualización externa: "Reproducir" para video/audio, "Abrir"
  /// para documentos. Lanza la URL firmada en el visor del sistema; si falla,
  /// avisa con un snackbar.
  Widget _openButton(BuildContext context, MediaAsset asset) {
    final ct = asset.contentType;
    final playable = ct.startsWith('video/') || ct.startsWith('audio/');
    return AppButton.filled(
      label: playable ? 'Reproducir' : 'Abrir',
      icon: playable ? Icons.play_arrow : Icons.open_in_new,
      onPressed: () async {
        final ok = await launcher.open(asset.previewUrl!);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('No se pudo abrir el archivo')),
            );
        }
      },
    );
  }

  /// Confirma antes de borrar (acción irreversible) y delega al cubit.
  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<MediaDetailCubit>();
    final ok = await showAppConfirmDialog(
      context,
      title: 'Borrar archivo',
      message:
          'Se quitará de la galería y de cualquier flujo que lo use. Esta '
          'acción no se puede deshacer.',
      confirmLabel: 'Borrar',
    );
    if (ok) await cubit.deleteAsset();
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

  /// Hay una imagen renderable que pintar: la imagen misma, o el poster/forma
  /// de onda derivado de un video/audio. Sin fuente (documento, o video/audio
  /// aún sin derivar) ⇒ ícono del tipo.
  bool get _hasRenderable => widget.asset.thumbnailSourceUrl != null;

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
          child: _hasRenderable ? _image() : _typeIcon(),
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
    mediaTypeIcon(widget.asset.contentType),
    color: AppTokens.text2,
    size: 64,
  );
}

/// Tarjeta de metadata: nombre, alias (si hay), tipo, tamaño, fecha y el ref
/// con botón de copiar. El ref es lo que se persiste en flujos, así que copiarlo
/// es de primera clase.
class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row(textTheme, 'Nombre', asset.filename),
          if (asset.alias.isNotEmpty) _row(textTheme, 'Alias', asset.alias),
          _row(textTheme, 'Tipo', asset.contentType),
          _row(textTheme, 'Tamaño', formatBytes(asset.size)),
          if ((asset.durationMs ?? 0) > 0)
            _row(textTheme, 'Duración', formatDuration(asset.durationMs!)),
          _row(textTheme, 'Subido', formatDate(asset.createdAt.toLocal())),
          const Divider(height: AppTokens.sp6, color: AppTokens.divider),
          _RefRow(ref: asset.ref),
        ],
      ),
    );
  }

  Widget _row(TextTheme textTheme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
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
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(
            'Referencia',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
        Expanded(
          child: Text(
            ref,
            // Monospace: el ref es un identificador, no prosa.
            style: textTheme.bodySmall?.copyWith(
              color: AppTokens.text2,
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
          onPressed: () =>
              copyTextToClipboard(context, ref, confirm: 'Referencia copiada'),
        ),
      ],
    );
  }
}
