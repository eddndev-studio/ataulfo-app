import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_page_container.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../bloc/media_gallery_bloc.dart';

/// Filtros de la galería de media: búsqueda por nombre y tabs por familia.
/// Ambos son disparadores delgados hacia el [MediaGalleryBloc]; la verdad de
/// los filtros activos vive en el bloc (espejada en [MediaGalleryLoaded]).

/// Campo de búsqueda por nombre (filename/alias). Debounced: dispara
/// [MediaGallerySearchChanged] 300 ms tras la última tecla, para no listar en
/// cada pulsación. El botón de limpiar resetea la búsqueda al instante.
class MediaGallerySearchField extends StatefulWidget {
  const MediaGallerySearchField({super.key});

  @override
  State<MediaGallerySearchField> createState() =>
      _MediaGallerySearchFieldState();
}

class _MediaGallerySearchFieldState extends State<MediaGallerySearchField> {
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
    if (value.isEmpty) {
      context.read<MediaGalleryBloc>().add(const MediaGallerySearchChanged(''));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<MediaGalleryBloc>().add(MediaGallerySearchChanged(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPrimaryPageContainer(
      top: AppTokens.sp3,
      child: AppSearchField(
        key: const Key('media_gallery.search_field'),
        hint: 'Buscar archivos por nombre…',
        controller: _controller,
        onChanged: _onChanged,
        clearButtonKey: const Key('media_gallery.search_clear'),
      ),
    );
  }
}

/// Tabs de filtro por familia. Mantiene la familia seleccionada localmente y
/// despacha [MediaGalleryTypeChanged] al cambiar; se re-sincroniza con el
/// filtro que expone [MediaGalleryLoaded]. 'Todos' = sin filtro (null).
class MediaGalleryTypeTabs extends StatefulWidget {
  const MediaGalleryTypeTabs({super.key});

  @override
  State<MediaGalleryTypeTabs> createState() => _MediaGalleryTypeTabsState();
}

class _MediaGalleryTypeTabsState extends State<MediaGalleryTypeTabs> {
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
    // "Limpiar filtros" del vacío filtrado): el estado Loaded expone el
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
          horizontal: AppPageGutters.primary,
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
