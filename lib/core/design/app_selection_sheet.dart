import 'package:flutter/material.dart';

import 'app_bottom_sheet.dart';
import 'safe_bottom.dart';
import 'tokens.dart';
import 'widgets/app_section_header.dart';
import 'widgets/app_text_field.dart';

/// Una opción elegible de [showAppSelectionSheet]: el valor de dominio que
/// representa y su presentación (glifo opcional, título y caption de una
/// línea). [key] viaja a la fila para que las pruebas del consumer la anclen
/// sin depender del texto.
class AppSelectionOption<T> {
  const AppSelectionOption({
    required this.value,
    required this.title,
    this.caption,
    this.leading,
    this.key,
  });

  final T value;
  final String title;

  /// Línea de apoyo bajo el título («ramifica según día y hora»). Null ⇒
  /// fila de una sola línea.
  final String? caption;

  /// Adorno a la izquierda (ícono, dot de color). Null ⇒ sin él.
  final Widget? leading;

  final Key? key;
}

/// Un grupo de opciones bajo un encabezado común ([AppSectionHeader]).
/// [header] null ⇒ grupo sin rótulo (lista plana).
class AppSelectionSection<T> {
  const AppSelectionSection({this.header, this.caption, required this.options});

  final String? header;

  /// Línea de apoyo del encabezado de sección. Solo aplica con [header].
  final String? caption;

  final List<AppSelectionOption<T>> options;
}

/// Selector rico del design system: hoja inferior con título, secciones de
/// opciones (glifo + título + caption + check de selección) y búsqueda
/// opcional. Es la forma canónica de «elegir de una lista» cuando las
/// opciones piden agrupación o explicación — la versión de una línea sin
/// grupos sigue siendo un sheet de `AppOptionRow` a mano.
///
/// Devuelve el valor de la opción tocada, o null si el operador descarta la
/// hoja (scrim, drag, atrás). Un dominio donde «ninguna» es una opción
/// legítima debe representarla como opción explícita (p. ej. envolviendo el
/// valor en un record), porque null ya significa «cerró sin elegir».
///
/// [selected] marca con el check de marca la opción cuyo valor sea igual
/// (`==`) a él. [searchHint] no nulo pinta un buscador fijo bajo el título
/// que filtra por título y caption ignorando mayúsculas y acentos; las
/// secciones sin coincidencias esconden también su encabezado.
Future<T?> showAppSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<AppSelectionSection<T>> sections,
  T? selected,
  String? searchHint,
}) {
  return showAppBottomSheet<T>(
    context,
    isScrollControlled: true,
    builder: (sheetContext) => _SelectionSheetBody<T>(
      title: title,
      sections: sections,
      selected: selected,
      searchHint: searchHint,
    ),
  );
}

class _SelectionSheetBody<T> extends StatefulWidget {
  const _SelectionSheetBody({
    required this.title,
    required this.sections,
    required this.selected,
    required this.searchHint,
  });

  final String title;
  final List<AppSelectionSection<T>> sections;
  final T? selected;
  final String? searchHint;

  @override
  State<_SelectionSheetBody<T>> createState() => _SelectionSheetBodyState<T>();
}

class _SelectionSheetBodyState<T> extends State<_SelectionSheetBody<T>> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Secciones visibles bajo el filtro vigente: cada una conserva solo sus
  /// opciones coincidentes y desaparece si se queda vacía.
  List<AppSelectionSection<T>> get _filtered {
    final query = _normalize(_searchController.text.trim());
    if (query.isEmpty) return widget.sections;
    return <AppSelectionSection<T>>[
      for (final section in widget.sections)
        if (section.options.any((o) => _matches(o, query)))
          AppSelectionSection<T>(
            header: section.header,
            caption: section.caption,
            options: <AppSelectionOption<T>>[
              for (final o in section.options)
                if (_matches(o, query)) o,
            ],
          ),
    ];
  }

  bool _matches(AppSelectionOption<T> option, String query) =>
      _normalize(option.title).contains(query) ||
      (option.caption != null && _normalize(option.caption!).contains(query));

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sections = _filtered;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.sp6,
          AppTokens.sp6,
          AppTokens.sp6,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Título y buscador quedan FIJOS: con listas largas el operador
            // no debe perder el contexto ni el campo de filtro al scrollear.
            Text(widget.title, style: textTheme.titleLarge),
            if (widget.searchHint != null) ...<Widget>[
              const SizedBox(height: AppTokens.sp4),
              AppTextField(
                label: 'Buscar',
                hint: widget.searchHint!,
                controller: _searchController,
                textInputAction: TextInputAction.search,
                prefixIcon: Icons.search,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: AppTokens.sp3),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: AppTokens.sp6 + context.sheetBottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.sp4,
                        ),
                        child: Text(
                          'Sin resultados',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTokens.text2,
                          ),
                        ),
                      ),
                    for (final section in sections) ...<Widget>[
                      if (section.header != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppTokens.sp3,
                            bottom: AppTokens.sp1,
                          ),
                          child: AppSectionHeader(
                            title: section.header!,
                            caption: section.caption,
                          ),
                        ),
                      for (final option in section.options)
                        _SelectionRow<T>(
                          key: option.key,
                          option: option,
                          selected:
                              widget.selected != null &&
                              option.value == widget.selected,
                          onTap: () =>
                              Navigator.of(context).pop<T>(option.value),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de una opción. Espeja la anatomía de `AppOptionRow` (InkWell de fila
/// completa, padding `sp3`/`sp1`, título en `bodyLarge` a una línea y check
/// de marca al final) y le añade la línea de caption bajo el título — la
/// variante de dos líneas que el selector rico necesita.
class _SelectionRow<T> extends StatelessWidget {
  const _SelectionRow({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppSelectionOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.sp3,
          horizontal: AppTokens.sp1,
        ),
        child: Row(
          children: <Widget>[
            if (option.leading != null) ...<Widget>[
              option.leading!,
              const SizedBox(width: AppTokens.sp3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    option.title,
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (option.caption != null)
                    Text(
                      option.caption!,
                      style: textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: AppTokens.sp2),
              const Icon(Icons.check, color: AppTokens.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// Minúsculas y sin acentos del español: la búsqueda no debe exigir teclear
/// la tilde exacta («condicion» encuentra «Condición»).
String _normalize(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');
