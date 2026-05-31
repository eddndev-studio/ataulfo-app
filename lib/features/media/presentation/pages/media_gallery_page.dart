import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
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
/// permite reusar la pantalla como picker: recibe el `ref` BARE, nunca la
/// previewUrl.
class MediaGalleryPage extends StatelessWidget {
  const MediaGalleryPage({super.key, this.onSelect});

  /// Selección de un asset (picker). Recibe el `ref` BARE — la identidad
  /// estable —, JAMÁS la `previewUrl` efímera. Null ⇒ la galería es sólo visor.
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    // Un error de subida es transitorio: lo anunciamos con un snackbar y la
    // lista sigue intacta (no colapsa a un estado de error terminal).
    return BlocListener<MediaGalleryBloc, MediaGalleryState>(
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
          MediaGalleryLoaded() => _LoadedView(state: state, onSelect: onSelect),
          MediaGalleryFailed() => const _FailedView(),
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('media_gallery.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar la galería',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<MediaGalleryBloc>().add(
                const MediaGalleryLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista cargada: grid de miniaturas con pull-to-refresh, scroll-infinito y un
/// FAB de subida. El grid y el FAB se montan en un Stack para que el botón
/// flote sobre el contenido (el Scaffold de la ruta no aporta floatingActionButton).
class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.state, required this.onSelect});

  final MediaGalleryLoaded state;
  final ValueChanged<String>? onSelect;

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
    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh: () async {
            final bloc = context.read<MediaGalleryBloc>();
            bloc.add(const MediaGalleryRefreshRequested());
            // Espera el fin del refresh: un Loaded ya no-refrescando (siempre
            // se emite gracias a la señal transitoria, aun si los datos no
            // cambian) o un Failed terminal.
            await bloc.stream.firstWhere(
              (s) =>
                  (s is MediaGalleryLoaded && !s.isRefreshing) ||
                  s is MediaGalleryFailed,
            );
          },
          child: state.items.isEmpty
              ? const _EmptyView()
              : _Grid(
                  controller: _controller,
                  state: state,
                  onSelect: widget.onSelect,
                ),
        ),
        Positioned(
          right: AppTokens.sp4,
          bottom: AppTokens.sp4 + context.safeBottomInset,
          child: _UploadFab(isUploading: state.isUploading),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.controller,
    required this.state,
    required this.onSelect,
  });

  final ScrollController controller;
  final MediaGalleryLoaded state;
  final ValueChanged<String>? onSelect;

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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
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
        return MediaThumbnail(
          asset: asset,
          // LINCHPIN: el picker recibe el ref BARE, nunca la previewUrl.
          onTap: onSelect == null ? null : () => onSelect!(asset.ref),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
                child: Text(
                  'Todavía no hay archivos en la galería',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
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
