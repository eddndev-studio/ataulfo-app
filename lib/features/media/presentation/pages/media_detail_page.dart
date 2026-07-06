import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_danger_zone.dart';
import '../../../../core/design/widgets/app_section_header.dart';
import '../../../../core/design/widgets/copy_text_actions.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_preview_launcher.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../bloc/media_detail_cubit.dart';
import '../media_format.dart';
import '../widgets/alias_edit_sheet.dart';
import 'media_detail_preview.dart';

/// Título del AppBar de `/media/detail`: el nombre amistoso del asset, vivo
/// desde el [MediaDetailCubit] (un renombrado se refleja sin recargar). El
/// chrome lo monta la ruta; la página es content-only.
class MediaDetailTitle extends StatelessWidget {
  const MediaDetailTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MediaDetailCubit, MediaDetailState>(
      builder: (context, state) =>
          Text(state.asset.displayName, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Detalle de un asset de la galería: previsualización + metadata + copiar la
/// referencia BARE + borrar. Content-only: la ruta monta Scaffold + AppBar
/// (con [MediaDetailTitle]); las mutaciones viven en la superficie — el alias
/// se edita desde su propia fila y el borrado cierra la página como
/// [AppDangerZone]. Cubit-driven: el [MediaDetailCubit] (inyectado por la ruta
/// con el asset abierto) es la verdad mostrada. Al borrar con éxito la página
/// hace pop devolviendo `true` para que la galería se refresque.
///
/// La previsualización ([MediaDetailPreview]) reproduce imagen/video/audio
/// DENTRO de la misma pantalla; sólo un documento (sin reproductor propio en
/// la app) ofrece abrir con el visor externo del sistema. La `previewUrl`
/// efímera NO es identidad; esa es [MediaAsset.ref].
class MediaDetailPage extends StatelessWidget {
  const MediaDetailPage({
    super.key,
    required this.loader,
    required this.launcher,
    this.readOnly = false,
  });

  final MediaThumbnailLoader loader;

  /// Abre en el visor del sistema lo que no se renderiza inline (documentos).
  final MediaPreviewLauncher launcher;

  /// Sólo mirar: oculta renombrar y la zona peligrosa. Es el modo del PREVIEW
  /// desde el picker (long-press), donde el operador elige, no administra.
  final bool readOnly;

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
        // Mutación en vuelo = controles inertes (el snapshot sigue pintado);
        // nunca un velo sobre la página.
        builder: (context, state) {
          final asset = state.asset;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp4,
              AppTokens.sp4,
              AppTokens.sp4,
              AppTokens.sp4 + context.safeBottomInset,
            ),
            children: <Widget>[
              MediaDetailPreview(asset: asset, loader: loader),
              if (_canOpenExternally(asset)) ...<Widget>[
                const SizedBox(height: AppTokens.sp4),
                _openButton(context, asset),
              ],
              const SizedBox(height: AppTokens.sp5),
              _MetadataCard(
                asset: asset,
                onEditAlias: readOnly || state.busy
                    ? null
                    : () => _editAlias(context),
              ),
              if (!readOnly) ...<Widget>[
                const SizedBox(height: AppTokens.sp7),
                AppDangerZone(
                  caption:
                      'Se quitará de la galería y de cualquier flujo que lo '
                      'use. No se puede deshacer.',
                  actions: <Widget>[
                    AppButton.danger(
                      key: const Key('media_detail.delete'),
                      label: 'Borrar archivo',
                      fullWidth: true,
                      loading: state.deleting,
                      onPressed: state.busy
                          ? null
                          : () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ],
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

  /// Se puede abrir en el visor del sistema SÓLO lo que no tiene reproductor
  /// propio dentro de la app (documentos): imagen se previsualiza inline;
  /// video y audio reproducen dentro de la misma pantalla ([MediaDetailPreview]).
  bool _canOpenExternally(MediaAsset asset) =>
      _isDocument(asset) && (asset.previewUrl?.isNotEmpty ?? false);

  bool _isDocument(MediaAsset asset) {
    final ct = asset.contentType;
    return !ct.startsWith('image/') &&
        !ct.startsWith('video/') &&
        !ct.startsWith('audio/');
  }

  /// Botón de apertura externa (documento sin visor propio en la app). Lanza
  /// la URL firmada en el visor del sistema; si falla, avisa con un snackbar.
  Widget _openButton(BuildContext context, MediaAsset asset) {
    return AppButton.filled(
      label: 'Abrir',
      icon: Icons.open_in_new,
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
      title: '¿Borrar este archivo?',
      message:
          'Se quitará de la galería y de cualquier flujo que lo use. Esta '
          'acción no se puede deshacer.',
      confirmLabel: 'Borrar',
    );
    if (ok) await cubit.deleteAsset();
  }
}

/// Ancho de la columna de labels de la metadata: alinea los valores de todas
/// las filas (incluida la de referencia) en una sola vertical.
const double _labelWidth = 88;

/// Tarjeta de metadata: nombre, alias (fila viva: tocarla renombra), tipo,
/// tamaño, fecha y el ref con botón de copiar. El ref es lo que se persiste en
/// flujos, así que copiarlo es de primera clase.
class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.asset, required this.onEditAlias});

  final MediaAsset asset;

  /// Abre el form-sheet de renombrar. Null = fila de alias inerte (readOnly o
  /// mutación en vuelo).
  final VoidCallback? onEditAlias;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'Detalles'),
          const SizedBox(height: AppTokens.sp2),
          _row(textTheme, 'Nombre', asset.filename),
          _AliasRow(alias: asset.alias, onEdit: onEditAlias),
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
          width: _labelWidth,
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

/// Fila del alias: el único campo editable del asset se edita DONDE se ve.
/// Siempre visible — sin alias es la affordance para ponerle uno («Sin
/// alias»). Con [onEdit] la fila entera es tocable y remata con el lápiz;
/// inerte (readOnly / mutación en vuelo) pinta solo el valor.
class _AliasRow extends StatelessWidget {
  const _AliasRow({required this.alias, required this.onEdit});

  final String alias;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: Text(
              'Alias',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
          Expanded(
            child: alias.isEmpty
                ? Text(
                    'Sin alias',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.text2,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(alias, style: textTheme.bodyMedium),
          ),
          if (onEdit != null)
            const Icon(Icons.edit_outlined, size: 18, color: AppTokens.text2),
        ],
      ),
    );
    if (onEdit == null) return row;
    return InkWell(
      key: const Key('media_detail.edit_alias'),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: onEdit,
      child: row,
    );
  }
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
          width: _labelWidth,
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
