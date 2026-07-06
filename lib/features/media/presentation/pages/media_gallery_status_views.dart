import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../bloc/media_gallery_bloc.dart';

/// Estados de pantalla completa de la galería de media: cargando, fallo
/// terminal de la primera página y vacío (virgen o filtrado sin resultados).

/// Primera carga: spinner canónico del kit.
class MediaGalleryLoadingView extends StatelessWidget {
  const MediaGalleryLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const AppLoadingIndicator();
}

/// Falla terminal de la primera página: card de error del kit con reintentar.
class MediaGalleryFailedView extends StatelessWidget {
  const MediaGalleryFailedView({super.key});

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

/// Vacío scrolleable (para que el pull-to-refresh siga funcionando).
class MediaGalleryEmptyView extends StatelessWidget {
  const MediaGalleryEmptyView({super.key, this.isFiltered = false});

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
                              onPressed: () => context
                                  .read<MediaGalleryBloc>()
                                  .add(const MediaGalleryFiltersCleared()),
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
