import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_color_swatch_picker.dart';
import '../../../../core/design/widgets/app_press_scale.dart';
import '../../../../core/design/widgets/app_section_header.dart';
import '../../domain/entities/catalog_appearance.dart';
import '../public_catalog_copy.dart';
import 'accent_palette.dart';
import 'catalog_design_preview.dart';

/// Sección «Apariencia» del catálogo público: elige uno de tres diseños
/// predefinidos (con preview pintada, teñida por el acento vigente) y uno de
/// trece colores primarios. Controlada: no guarda ni conserva estado propio;
/// emite [onDesignChanged] / [onAccentChanged] y es el formulario quien decide
/// el nuevo valor y cuándo persistir.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    super.key,
    required this.design,
    required this.accent,
    required this.onDesignChanged,
    required this.onAccentChanged,
    this.showOffHint = false,
  });

  final CatalogDesign design;
  final CatalogAccent accent;
  final ValueChanged<CatalogDesign> onDesignChanged;
  final ValueChanged<CatalogAccent> onAccentChanged;

  /// Cuando el catálogo está apagado la apariencia se guarda igual, pero no se
  /// ve hasta encenderlo: un hint honesto lo dice.
  final bool showOffHint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(
          title: catalogAppearanceTitle,
          caption: catalogAppearanceCaption,
        ),
        if (showOffHint) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          const _OffHint(),
        ],
        const SizedBox(height: AppTokens.sp4),
        const _SubLabel(catalogDesignLabel),
        const SizedBox(height: AppTokens.sp3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final d in CatalogDesign.values) ...<Widget>[
              if (d != CatalogDesign.values.first)
                const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: _DesignOption(
                  design: d,
                  accent: accent,
                  selected: d == design,
                  onTap: () => onDesignChanged(d),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTokens.sp3),
        Text(
          catalogDesignDescription(design),
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp5),
        const _SubLabel(catalogAccentLabel),
        const SizedBox(height: AppTokens.sp3),
        AppColorSwatchPicker(
          options: <AppColorSwatchOption>[
            for (final a in CatalogAccent.values)
              AppColorSwatchOption(
                key: Key('public_catalog.accent.${a.wire}'),
                selected: a == accent,
                onTap: () => onAccentChanged(a),
                swatch: _AccentDot(accent: a),
              ),
          ],
        ),
      ],
    );
  }
}

/// Etiqueta de un subselector (Diseño / Color primario): atenuada, en negrita.
class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppTokens.text2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Aviso de que la apariencia solo se ve con el catálogo encendido.
class _OffHint extends StatelessWidget {
  const _OffHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.info_outline, size: 16, color: AppTokens.text2),
        const SizedBox(width: AppTokens.sp2),
        Expanded(
          child: Text(
            catalogAppearanceOffHint,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
      ],
    );
  }
}

/// Una opción del selector de diseño: tarjeta seleccionable con la preview
/// pintada y el nombre del diseño. Realce de selección con borde de marca (el
/// lenguaje del kit para "activo"); encoge al presionar respetando AppMotion.
class _DesignOption extends StatefulWidget {
  const _DesignOption({
    required this.design,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final CatalogDesign design;
  final CatalogAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesignOption> createState() => _DesignOptionState();
}

class _DesignOptionState extends State<_DesignOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final radius = BorderRadius.circular(AppTokens.radiusMd);
    final name = catalogDesignName(widget.design);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: AppPressScale(
        pressed: _pressed,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('public_catalog.design.${widget.design.wire}'),
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Container(
              padding: const EdgeInsets.all(AppTokens.sp2),
              decoration: BoxDecoration(
                color: AppTokens.surface2,
                borderRadius: radius,
                // Borde de 2px en ambos estados (marca / divider) para que la
                // geometría no salte al seleccionar.
                border: Border.all(
                  color: selected ? AppTokens.primary : AppTokens.divider,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CatalogDesignPreview(
                    design: widget.design,
                    accent: widget.accent,
                  ),
                  const SizedBox(height: AppTokens.sp2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTokens.primary : AppTokens.text1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo de color (relleno = vivo del acento) para un swatch del picker. El
/// tooltip lleva el nombre es-MX; el swatch mango marca «Predeterminado».
class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.accent});

  final CatalogAccent accent;

  @override
  Widget build(BuildContext context) {
    final name = catalogAccentName(accent);
    final tooltip = accent == CatalogAccent.mango
        ? '$name ($catalogAccentDefaultTag)'
        : name;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: accentSpec(accent).vivo,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
