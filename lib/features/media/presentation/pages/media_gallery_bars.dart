import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../bloc/media_gallery_bloc.dart';

/// Barras contextuales y acciones flotantes de la galería de media: progreso
/// de subida, selección-para-borrar, confirmación del multi-picker, error de
/// paginación y el FAB de subida.

/// Barra de progreso de una subida en lote: "Subiendo N de M…" + barra. La
/// barra es indeterminada hasta el primer archivo (done 0), luego proporcional.
class MediaGalleryUploadProgressBar extends StatelessWidget {
  const MediaGalleryUploadProgressBar({
    super.key,
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp4,
              vertical: AppTokens.sp2,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'Subiendo $done de $total…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: done == 0 ? null : done / total,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.primary),
            backgroundColor: AppTokens.surface2,
          ),
        ],
      ),
    );
  }
}

/// Barra contextual del modo selección (browse): cuántos hay, limpiar y borrar
/// en lote (con confirmación). Despacha al [MediaGalleryBloc].
class MediaGallerySelectionBar extends StatelessWidget {
  const MediaGallerySelectionBar({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MediaGalleryBloc>();
    return Material(
      color: AppTokens.surface3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp2),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('media_gallery.selection_clear'),
              tooltip: 'Cancelar selección',
              icon: const Icon(Icons.close),
              onPressed: () => bloc.add(const MediaGallerySelectionCleared()),
            ),
            Expanded(
              child: Text(
                '$count seleccionado${count == 1 ? '' : 's'}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              key: const Key('media_gallery.selection_delete'),
              tooltip: 'Borrar seleccionados',
              icon: const Icon(Icons.delete_outline),
              color: AppTokens.danger,
              onPressed: () => _confirmBatchDelete(context, bloc, count),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBatchDelete(
    BuildContext context,
    MediaGalleryBloc bloc,
    int count,
  ) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Borrar $count archivo${count == 1 ? '' : 's'}',
      message:
          'Se quitarán de la galería y de cualquier flujo que los use. Esta '
          'acción no se puede deshacer.',
      confirmLabel: 'Borrar',
    );
    if (ok) bloc.add(const MediaGalleryDeleteSelectedRequested());
  }
}

/// Barra del multi-picker: cuántos hay marcados, limpiar y confirmar (entrega
/// los assets al caller en orden de tap). Espeja la forma de la barra de
/// selección de browse para que ambas se lean como el mismo patrón.
class MediaGalleryMultiConfirmBar extends StatelessWidget {
  const MediaGalleryMultiConfirmBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onConfirm,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp2),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('media_gallery.multi_clear'),
              tooltip: 'Cancelar selección',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
            Expanded(
              child: Text(
                '$count seleccionado${count == 1 ? '' : 's'}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            AppButton.tonal(
              key: const Key('media_gallery.multi_confirm'),
              label: 'Agregar',
              onPressed: onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de error de paginación al pie del grid: el fallo de load-more no
/// tumba la lista visible, pero tampoco puede ser silencioso — el operador
/// ve el motivo y reintenta en el lugar donde ocurrió.
class MediaGalleryLoadMoreErrorBar extends StatelessWidget {
  const MediaGalleryLoadMoreErrorBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTokens.surface2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp1,
        ),
        child: Row(
          children: <Widget>[
            const Expanded(child: Text('No se pudo cargar más')),
            AppButton.text(
              label: 'Reintentar',
              onPressed: () => context.read<MediaGalleryBloc>().add(
                const MediaGalleryLoadMoreRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FAB de subida. Mientras [isUploading] gira un spinner y bloquea el tap para
/// no encolar una segunda subida.
class MediaGalleryUploadFab extends StatelessWidget {
  const MediaGalleryUploadFab({super.key, required this.isUploading});

  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const Key('media_gallery.upload_fab'),
      backgroundColor: AppTokens.primary,
      foregroundColor: AppTokens.onPrimary,
      onPressed: isUploading
          ? null
          : () => context.read<MediaGalleryBloc>().add(
              const MediaGalleryUploadRequested(),
            ),
      child: isUploading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.onPrimary),
              ),
            )
          : const Icon(Icons.upload_outlined),
    );
  }
}
