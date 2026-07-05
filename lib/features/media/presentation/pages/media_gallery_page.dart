import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/repositories/media_thumbnail_loader.dart';
import '../../domain/entities/media_asset.dart';
import '../bloc/media_gallery_bloc.dart';
import '../widgets/media_thumbnail.dart';

/// Galería de media de la organización (content-only: Scaffold + AppBar los
/// aporta la ruta). Lista los assets en un grid de miniaturas con paginación
/// load-more y permite subir un archivo nuevo vía el puerto FilePicker.
///
/// La paginación vive en el [MediaGalleryBloc]; esta página es un disparador
/// delgado: un scroll cerca del fondo despacha [MediaGalleryLoadMoreRequested]
/// y el bloc decide si hay algo que cargar. El callback [onSelect] (opcional)
/// permite reusar la pantalla como picker: recibe el [MediaAsset] completo.
class MediaGalleryPage extends StatelessWidget {
  const MediaGalleryPage({
    super.key,
    required this.loader,
    this.onSelect,
    this.onOpenDetail,
    this.showTypeTabs = false,
  });

  /// Resuelve los bytes de cada miniatura (cache local por ref → red). Inyectado
  /// desde la composición para que el cache de bytes sea un singleton de sesión.
  final MediaThumbnailLoader loader;

  /// Selección de un asset (picker). Recibe el [MediaAsset] completo (ref +
  /// content_type + filename) para que el caller alinee tipo↔asset y persista
  /// el filename del documento. El CONSUMIDOR debe usar `asset.ref` (BARE) como
  /// identidad y NUNCA persistir `asset.previewUrl` (firmada efímera). Null ⇒ no
  /// es picker (modo browse: ver [onOpenDetail]).
  final ValueChanged<MediaAsset>? onSelect;

  /// Abre el detalle de un asset (modo browse). Devuelve `true` si el detalle
  /// reportó un cambio (borrado/renombrado) ⇒ la galería se refresca. Tiene
  /// prioridad menor que [onSelect]: si hay picker, el tap selecciona. Null y sin
  /// [onSelect] ⇒ la galería es sólo visor (tap inerte).
  final Future<bool> Function(MediaAsset asset)? onOpenDetail;

  /// Muestra las tabs de filtro por familia (image|video|audio|document). Sólo
  /// en browse: en el picker el tipo lo fija el paso de flujo y cambiarlo
  /// rompería esa restricción, así que ahí queda en false.
  final bool showTypeTabs;

  @override
  Widget build(BuildContext context) {
    // El campo de búsqueda vive ARRIBA del switch de estado: persiste mientras
    // la lista carga/se vacía, para poder limpiar una búsqueda sin resultados.
    // Un error de subida es transitorio: snackbar y la lista sigue intacta.
    return Column(
      children: <Widget>[
        const _SearchField(),
        if (showTypeTabs) const _TypeTabs(),
        Expanded(
          child: BlocListener<MediaGalleryBloc, MediaGalleryState>(
            listenWhen: (prev, curr) =>
                curr is MediaGalleryLoaded && curr.uploadError != null,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('No pudimos subir el archivo')),
                );
            },
            child: BlocBuilder<MediaGalleryBloc, MediaGalleryState>(
              builder: (context, state) => switch (state) {
                MediaGalleryInitial() ||
                MediaGalleryLoading() => const _LoadingView(),
                MediaGalleryLoaded() => _LoadedView(
                  state: state,
                  onSelect: onSelect,
                  onOpenDetail: onOpenDetail,
                  loader: loader,
                ),
                MediaGalleryFailed() => const _FailedView(),
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo de búsqueda por nombre (filename/alias). Debounced: dispara
/// [MediaGallerySearchChanged] 300 ms tras la última tecla, para no listar en
/// cada pulsación. El botón de limpiar resetea la búsqueda al instante.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<MediaGalleryBloc>().add(MediaGallerySearchChanged(value));
    });
    setState(() {}); // refresca la visibilidad del botón limpiar
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    context.read<MediaGalleryBloc>().add(const MediaGallerySearchChanged(''));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp3,
        AppTokens.sp4,
        0,
      ),
      child: AppTextField(
        key: const Key('media_gallery.search_field'),
        label: 'Buscar archivo',
        hint: 'Buscar por nombre',
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        prefixIcon: Icons.search,
        suffix: _controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('media_gallery.search_clear'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: AppTokens.text2),
                onPressed: _clear,
              ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const AppLoadingIndicator();
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          key: const Key('media_gallery.error'),
          message: 'No pudimos cargar la galería',
          onRetry: () => context.read<MediaGalleryBloc>().add(
            const MediaGalleryLoadRequested(),
          ),
        ),
      ),
    );
  }
}

/// Tabs de filtro por familia (browse). Mantiene la familia seleccionada
/// localmente (el bloc no la expone en su estado) y despacha
/// [MediaGalleryTypeChanged] al cambiar. 'Todos' = sin filtro (null).
class _TypeTabs extends StatefulWidget {
  const _TypeTabs();

  @override
  State<_TypeTabs> createState() => _TypeTabsState();
}

class _TypeTabsState extends State<_TypeTabs> {
  static const List<(String?, String)> _families = <(String?, String)>[
    (null, 'Todos'),
    ('image', 'Imágenes'),
    ('video', 'Video'),
    ('audio', 'Audio'),
    ('document', 'Documentos'),
  ];

  String? _selected;

  void _select(String? family) {
    if (family == _selected) return;
    setState(() => _selected = family);
    context.read<MediaGalleryBloc>().add(MediaGalleryTypeChanged(family));
  }

  @override
  Widget build(BuildContext context) {
    // Sincroniza con el bloc cuando el tipo cambió fuera de las tabs (p.ej.
    // "Limpiar filtros" del vacío filtrado): el estado Loaded ahora expone el
    // filtro activo y esta vista lo espeja en vez de divergir.
    final blocState = context.watch<MediaGalleryBloc>().state;
    if (blocState is MediaGalleryLoaded && blocState.type != _selected) {
      _selected = blocState.type;
    }
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp2,
        ),
        children: <Widget>[
          for (final (String? family, String label) in _families)
            Padding(
              padding: const EdgeInsets.only(right: AppTokens.sp2),
              child: AppChoiceChip(
                key: Key('media_gallery.type_chip.${family ?? 'all'}'),
                label: label,
                selected: _selected == family,
                onSelected: (_) => _select(family),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vista cargada: grid de miniaturas con pull-to-refresh, scroll-infinito y un
/// FAB de subida. El grid y el FAB se montan en un Stack para que el botón
/// flote sobre el contenido (el Scaffold de la ruta no aporta floatingActionButton).
class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.state,
    required this.onSelect,
    required this.onOpenDetail,
    required this.loader,
  });

  final MediaGalleryLoaded state;
  final ValueChanged<MediaAsset>? onSelect;
  final Future<bool> Function(MediaAsset asset)? onOpenDetail;
  final MediaThumbnailLoader loader;

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
          _SelectionBar(count: state.selectedRefs.length),
        // Progreso de subida en lote: "Subiendo N de M…" + barra.
        if (state.uploadTotal > 0)
          _UploadProgressBar(done: state.uploadDone, total: state.uploadTotal),
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
                    ? _EmptyView(isFiltered: state.isFiltered)
                    : _Grid(
                        controller: _controller,
                        state: state,
                        onSelect: widget.onSelect,
                        onOpenDetail: widget.onOpenDetail,
                        loader: widget.loader,
                      ),
              ),
              if (!state.selectionMode)
                Positioned(
                  right: AppTokens.sp4,
                  bottom: AppTokens.sp4 + context.safeBottomInset,
                  child: _UploadFab(isUploading: state.isUploading),
                ),
              if (state.isDeleting)
                Positioned.fill(
                  child: ColoredBox(
                    color: AppTokens.scrim,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTokens.primary,
                            ),
                          ),
                          const SizedBox(height: AppTokens.sp3),
                          Text(
                            state.deleteTotal == 1
                                ? 'Borrando archivo…'
                                : 'Borrando ${state.deleteDone} de '
                                      '${state.deleteTotal}…',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (state.loadMoreError != null && !state.isLoadingMore)
          const _LoadMoreErrorBar(),
      ],
    );
  }
}

/// Barra de progreso de una subida en lote: "Subiendo N de M…" + barra. La
/// barra es indeterminada hasta el primer archivo (done 0), luego proporcional.
class _UploadProgressBar extends StatelessWidget {
  const _UploadProgressBar({required this.done, required this.total});

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

/// Barra contextual del modo selección: cuántos hay, limpiar y borrar en lote
/// (con confirmación). Despacha al [MediaGalleryBloc].
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count});

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

class _Grid extends StatelessWidget {
  const _Grid({
    required this.controller,
    required this.state,
    required this.onSelect,
    required this.onOpenDetail,
    required this.loader,
  });

  final ScrollController controller;
  final MediaGalleryLoaded state;
  final ValueChanged<MediaAsset>? onSelect;
  final Future<bool> Function(MediaAsset asset)? onOpenDetail;
  final MediaThumbnailLoader loader;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    // Una fila extra para el indicador de paginación cuando hay una página en
    // vuelo; así el spinner viaja al final del grid sin desplazar las celdas.
    final showFooter = state.isLoadingMore;
    return GridView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4,
        // Deja aire para que el FAB no tape la última fila.
        AppTokens.sp9 + context.safeBottomInset,
      ),
      // Columnas según el ancho disponible (no 3 fijas): en móvil da ~3, en
      // desktop ancho llena con más sin estirar las celdas. El extent acota el
      // tamaño máximo de cada miniatura; las celdas son cuadradas (el caption
      // del displayName flota dentro, no añade alto).
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: AppTokens.sp3,
        crossAxisSpacing: AppTokens.sp3,
      ),
      itemCount: items.length + (showFooter ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Center(
            key: Key('media_gallery.load_more_indicator'),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              ),
            ),
          );
        }
        final MediaAsset asset = items[i];
        // La selección múltiple es de browse (no picker): long-press entra/
        // alterna; en modo selección el tap también alterna. Fuera de selección,
        // el tap abre detalle (browse) o selecciona-y-popea (picker).
        final canSelect = onSelect == null;
        final VoidCallback? onLongPress = canSelect
            ? () => context.read<MediaGalleryBloc>().add(
                MediaGallerySelectionToggled(asset.ref),
              )
            : null;
        return MediaThumbnail(
          asset: asset,
          loader: loader,
          selected: state.selectedRefs.contains(asset.ref),
          onLongPress: onLongPress,
          onTap: (canSelect && state.selectionMode)
              ? onLongPress
              : _tapHandler(context, asset),
        );
      },
    );
  }

  /// Gesto del tap según el modo. Picker ([onSelect]): selecciona (el consumidor
  /// usa `asset.ref` BARE, nunca persiste la previewUrl). Browse ([onOpenDetail]):
  /// abre el detalle y, si reportó un cambio (borrado/renombrado), refresca la
  /// galería. Sin ninguno ⇒ tap inerte (sólo visor). El `context` aquí está bajo
  /// el [MediaGalleryBloc], así que puede despachar el refresh.
  VoidCallback? _tapHandler(BuildContext context, MediaAsset asset) {
    if (onSelect != null) return () => onSelect!(asset);
    final open = onOpenDetail;
    if (open == null) return null;
    return () async {
      final changed = await open(asset);
      if (changed && context.mounted) {
        context.read<MediaGalleryBloc>().add(
          const MediaGalleryRefreshRequested(),
        );
      }
    };
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({this.isFiltered = false});

  /// Hay búsqueda o filtro de tipo activos: el vacío significa "sin
  /// resultados", no "galería virgen", y ofrece limpiar los filtros.
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              key: const Key('media_gallery.empty'),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.sp6),
                // Filtrado = "sin resultados" (texto plano + limpiar, como los
                // no-results de bots/plantillas). Virgen = vacío rico del kit,
                // sin CTA: el FAB de subida ya está en pantalla.
                child: isFiltered
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Sin resultados para esta búsqueda',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTokens.sp3),
                          Builder(
                            builder: (context) => AppButton.text(
                              label: 'Limpiar filtros',
                              onPressed: () => context.read<MediaGalleryBloc>()
                                ..add(const MediaGallerySearchChanged(''))
                                ..add(const MediaGalleryTypeChanged(null)),
                            ),
                          ),
                        ],
                      )
                    : const AppEmptyState(
                        icon: Icons.perm_media_outlined,
                        title: 'Todavía no hay archivos en la galería',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FAB de subida. Mientras [isUploading] gira un spinner y bloquea el tap para
/// no encolar una segunda subida.
class _UploadFab extends StatelessWidget {
  const _UploadFab({required this.isUploading});

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

/// Barra de error de paginación al pie del grid: el fallo de load-more no
/// tumba la lista visible, pero tampoco puede ser silencioso — el operador
/// ve el motivo y reintenta en el lugar donde ocurrió.
class _LoadMoreErrorBar extends StatelessWidget {
  const _LoadMoreErrorBar();

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
