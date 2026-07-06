import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../bloc/media_gallery_bloc.dart';
import 'media_gallery_bars.dart';
import 'media_gallery_filter_bar.dart';
import 'media_gallery_grid.dart';
import 'media_gallery_status_views.dart';

/// Galería de media de la organización (content-only: Scaffold + AppBar los
/// aporta la ruta). Host delgado: compone los filtros
/// ([MediaGallerySearchField]/[MediaGalleryTypeTabs]), las barras contextuales
/// (media_gallery_bars.dart), el grid ([MediaGalleryGrid]) y los estados de
/// pantalla completa (media_gallery_status_views.dart) — cada pieza vive en su
/// archivo hermano.
///
/// La paginación vive en el [MediaGalleryBloc]; esta página es un disparador
/// delgado: un scroll cerca del fondo despacha [MediaGalleryLoadMoreRequested]
/// y el bloc decide si hay algo que cargar. Los callbacks [onSelect] /
/// [onConfirmSelection] (opcionales) permiten reusar la pantalla como picker
/// de uno o de varios; ambos entregan [MediaAsset] completos.
class MediaGalleryPage extends StatefulWidget {
  const MediaGalleryPage({
    super.key,
    required this.loader,
    this.onSelect,
    this.onConfirmSelection,
    this.onOpenDetail,
    this.showTypeTabs = false,
  });

  /// Resuelve los bytes de cada miniatura (cache local por ref → red). Inyectado
  /// desde la composición para que el cache de bytes sea un singleton de sesión.
  final MediaThumbnailLoader loader;

  /// Selección de un asset (picker de UNO). Recibe el [MediaAsset] completo
  /// (ref + content_type + filename) para que el caller alinee tipo↔asset y
  /// persista el filename del documento. El CONSUMIDOR debe usar `asset.ref`
  /// (BARE) como identidad y NUNCA persistir `asset.previewUrl` (firmada
  /// efímera). Null ⇒ no es picker single (ver [onConfirmSelection] y
  /// [onOpenDetail]).
  final ValueChanged<MediaAsset>? onSelect;

  /// Picker de VARIOS: el tap alterna la selección local y una barra de
  /// confirmar entrega la lista (mismo contrato BARE-ref que [onSelect], en
  /// orden de tap). Tiene prioridad sobre [onSelect]. Null ⇒ no hay
  /// multi-selección.
  final ValueChanged<List<MediaAsset>>? onConfirmSelection;

  /// Abre el detalle de un asset. En browse lo dispara el tap; en los modos
  /// picker lo dispara el long-press como PREVIEW (ver en grande antes de
  /// elegir). Devuelve `true` si el detalle reportó un cambio
  /// (borrado/renombrado) ⇒ la galería se refresca. Null y sin picker ⇒ la
  /// galería es sólo visor (tap inerte).
  final Future<bool> Function(MediaAsset asset)? onOpenDetail;

  /// Muestra las tabs de filtro por familia (image|video|audio|document).
  /// Aplica en browse y en pickers SIN tipo fijo; un picker abierto con la
  /// familia fijada por el paso de flujo las deja en false (cambiarla
  /// rompería esa restricción).
  final bool showTypeTabs;

  @override
  State<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<MediaGalleryPage> {
  /// Selección local del multi-picker (ref → asset, en orden de tap). Vive en
  /// la página y no en el bloc: es la SALIDA del picker (assets completos para
  /// el caller), no el modo selección-para-borrar de browse, y así sobrevive
  /// los pasos por Loading al cambiar filtros.
  final Map<String, MediaAsset> _picked = <String, MediaAsset>{};

  bool get _multiMode => widget.onConfirmSelection != null;

  void _togglePick(MediaAsset asset) {
    setState(() {
      if (_picked.remove(asset.ref) == null) _picked[asset.ref] = asset;
    });
  }

  @override
  Widget build(BuildContext context) {
    // El campo de búsqueda vive ARRIBA del switch de estado: persiste mientras
    // la lista carga/se vacía, para poder limpiar una búsqueda sin resultados.
    // Un error de subida es transitorio: snackbar y la lista sigue intacta.
    return Column(
      children: <Widget>[
        const MediaGallerySearchField(),
        if (widget.showTypeTabs) const MediaGalleryTypeTabs(),
        if (_multiMode && _picked.isNotEmpty)
          MediaGalleryMultiConfirmBar(
            count: _picked.length,
            onClear: () => setState(_picked.clear),
            onConfirm: () =>
                widget.onConfirmSelection!(_picked.values.toList()),
          ),
        Expanded(
          child: BlocListener<MediaGalleryBloc, MediaGalleryState>(
            // Sólo la TRANSICIÓN a un outcome nuevo (no cada rebuild que lo
            // arrastre por copyWith), para no duplicar snackbars.
            listenWhen: (prev, curr) =>
                curr is MediaGalleryLoaded &&
                curr.uploadOutcome != null &&
                (prev is! MediaGalleryLoaded ||
                    prev.uploadOutcome != curr.uploadOutcome),
            listener: (context, state) => _notifyUploadOutcome(
              context,
              (state as MediaGalleryLoaded).uploadOutcome!,
            ),
            child: BlocBuilder<MediaGalleryBloc, MediaGalleryState>(
              builder: (context, state) => switch (state) {
                MediaGalleryInitial() ||
                MediaGalleryLoading() => const MediaGalleryLoadingView(),
                MediaGalleryLoaded() => _LoadedView(
                  state: state,
                  onSelect: widget.onSelect,
                  onOpenDetail: widget.onOpenDetail,
                  loader: widget.loader,
                  pickedRefs: _picked.keys.toSet(),
                  onTogglePick: _multiMode ? _togglePick : null,
                ),
                MediaGalleryFailed() => const MediaGalleryFailedView(),
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Feedback del lote de subida. Fallos ⇒ snackbar con el conteo real (no
  /// sólo el último error). Todo subido pero oculto por el filtro activo ⇒
  /// aviso con "Ver todo" que limpia los filtros — sin él, el archivo recién
  /// subido "desaparece" en silencio del grid filtrado.
  void _notifyUploadOutcome(BuildContext context, MediaUploadOutcome outcome) {
    final bloc = context.read<MediaGalleryBloc>();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (outcome.failed > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome.total == 1
                ? 'No pudimos subir el archivo'
                : 'No pudimos subir ${outcome.failed} de '
                      '${outcome.total} archivos',
          ),
        ),
      );
      return;
    }
    if (outcome.lastError != null) {
      // Subió todo, pero el re-list final falló: la lista visible quedó vieja.
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos actualizar la galería')),
      );
      return;
    }
    if (outcome.hiddenByFilter) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Subido, pero oculto por el filtro activo'),
          action: SnackBarAction(
            label: 'Ver todo',
            onPressed: () => bloc.add(const MediaGalleryFiltersCleared()),
          ),
        ),
      );
    }
  }
}

/// Vista cargada: grid de miniaturas con pull-to-refresh, scroll-infinito y un
/// FAB de subida. El grid y el FAB se montan en un Stack para que el botón
/// flote sobre el contenido (el Scaffold de la ruta no aporta
/// floatingActionButton). Durante un borrado en lote muestra el scrim de
/// progreso con cancelar.
class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.state,
    required this.onSelect,
    required this.onOpenDetail,
    required this.loader,
    this.pickedRefs = const <String>{},
    this.onTogglePick,
  });

  final MediaGalleryLoaded state;
  final ValueChanged<MediaAsset>? onSelect;
  final Future<bool> Function(MediaAsset asset)? onOpenDetail;
  final MediaThumbnailLoader loader;

  /// Refs marcados por el multi-picker (selección local de la página).
  final Set<String> pickedRefs;

  /// Alterna la selección local del multi-picker; null ⇒ no hay multi.
  final ValueChanged<MediaAsset>? onTogglePick;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Disparador delgado: cerca del fondo pide la siguiente página. El bloc
  /// guarda contra paginar sin cursor o con una página ya en vuelo, así que
  /// despachar de más es inocuo.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      context.read<MediaGalleryBloc>().add(
        const MediaGalleryLoadMoreRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      children: <Widget>[
        // Barra de selección (sólo en modo selección): contador + limpiar +
        // borrar en lote. Sustituye al FAB de subida mientras está activa.
        if (state.selectionMode)
          MediaGallerySelectionBar(count: state.selectedRefs.length),
        // Progreso de subida en lote: "Subiendo N de M…" + barra.
        if (state.uploadTotal > 0)
          MediaGalleryUploadProgressBar(
            done: state.uploadDone,
            total: state.uploadTotal,
          ),
        Expanded(
          child: Stack(
            children: <Widget>[
              RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<MediaGalleryBloc>();
                  bloc.add(const MediaGalleryRefreshRequested());
                  // Espera el fin del refresh: un Loaded ya no-refrescando
                  // (siempre se emite gracias a la señal transitoria, aun si los
                  // datos no cambian) o un Failed terminal.
                  await bloc.stream.firstWhere(
                    (s) =>
                        (s is MediaGalleryLoaded && !s.isRefreshing) ||
                        s is MediaGalleryFailed,
                  );
                },
                child: state.items.isEmpty
                    ? MediaGalleryEmptyView(isFiltered: state.isFiltered)
                    : MediaGalleryGrid(
                        controller: _controller,
                        state: state,
                        onSelect: widget.onSelect,
                        onOpenDetail: widget.onOpenDetail,
                        loader: widget.loader,
                        pickedRefs: widget.pickedRefs,
                        onTogglePick: widget.onTogglePick,
                      ),
              ),
              if (!state.selectionMode)
                Positioned(
                  right: AppTokens.sp4,
                  bottom: AppTokens.sp4 + context.safeBottomInset,
                  child: MediaGalleryUploadFab(isUploading: state.isUploading),
                ),
              if (state.isDeleting) _DeleteScrim(state: state),
            ],
          ),
        ),
        if (state.loadMoreError != null && !state.isLoadingMore)
          const MediaGalleryLoadMoreErrorBar(),
      ],
    );
  }
}

/// Scrim del borrado en lote: progreso "Borrando X de Y…" + cancelar.
class _DeleteScrim extends StatelessWidget {
  const _DeleteScrim({required this.state});

  final MediaGalleryLoaded state;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppTokens.scrim,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              ),
              const SizedBox(height: AppTokens.sp3),
              Text(
                state.deleteTotal == 1
                    ? 'Borrando archivo…'
                    : 'Borrando ${state.deleteDone} de '
                          '${state.deleteTotal}…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTokens.sp3),
              // El lote es secuencial y puede ser largo: cancelar deja de
              // emitir deletes (lo ya borrado, borrado queda) y cierra el
              // scrim al re-listar.
              AppButton.text(
                key: const Key('media_gallery.delete_cancel'),
                label: 'Cancelar',
                onPressed: () => context.read<MediaGalleryBloc>().add(
                  const MediaGalleryDeleteCancelRequested(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
