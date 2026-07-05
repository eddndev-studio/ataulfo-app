import 'package:flutter/material.dart';

import '../tokens.dart';

/// Color del dot opcional que aparece a la izquierda del label.
enum AppPillDot { active, paused, danger }

/// Variantes visuales del [AppPill]. Privada — los callsites usan los
/// constructores con nombre (.primary, .neutral, .danger, .outline, .glass).
enum _AppPillVariant { primary, neutral, danger, outline, glass }

/// Primitivo Pill / Badge del design system.
///
/// Reemplaza al `Chip` de Material: no respeta el theme legacy (tokens
/// duros), tipografía caption 12/16/500 y padding 4/10 idénticos en todas
/// las variantes. Toda variante es una cápsula (radio full): el badge es
/// pequeño y el pill pleno comunica estado mejor que un chip cuadrado. El
/// dot opcional sirve como indicador de estado al lado del label sin
/// necesidad de iconos extra.
class AppPill extends StatelessWidget {
  const AppPill.primary({super.key, required this.label, this.icon, this.dot})
    : _variant = _AppPillVariant.primary,
      assert(icon == null || dot == null, _iconDotExclusive);

  const AppPill.neutral({super.key, required this.label, this.icon, this.dot})
    : _variant = _AppPillVariant.neutral,
      assert(icon == null || dot == null, _iconDotExclusive);

  const AppPill.danger({super.key, required this.label, this.icon, this.dot})
    : _variant = _AppPillVariant.danger,
      assert(icon == null || dot == null, _iconDotExclusive);

  const AppPill.outline({super.key, required this.label, this.icon, this.dot})
    : _variant = _AppPillVariant.outline,
      assert(icon == null || dot == null, _iconDotExclusive);

  /// Cápsula de vidrio para fondos vivos (el gradiente de marca): velo oscuro
  /// translúcido con label `onPrimary`. Hermana de `AppCard.glass`; reemplaza a
  /// las demás variantes cuando el pill va SOBRE el gradiente (donde el fill
  /// amarillo de `.primary` o el surface oscuro de `.neutral` no leerían).
  const AppPill.glass({super.key, required this.label, this.icon, this.dot})
    : _variant = _AppPillVariant.glass,
      assert(icon == null || dot == null, _iconDotExclusive);

  final String label;
  final _AppPillVariant _variant;

  /// Glifo opcional a la izquierda del label, del mismo color que el texto y a
  /// escala de la tipografía caption. Excluyente con [dot]: ambos ocupan el
  /// mismo lugar y comunicarían dos cosas a la vez.
  final IconData? icon;
  final AppPillDot? dot;

  /// Tamaño del glifo: dos pasos sobre el caption (12) para leerse junto al
  /// texto sin dominar la cápsula.
  static const double _iconSize = 14.0;

  static const String _iconDotExclusive =
      'AppPill: icon y dot son mutuamente excluyentes';

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(_variant);
    // El Row con mainAxisSize.min ya ajusta el ancho al contenido: no hace
    // falta envolver en IntrinsicWidth.
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: colors.border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (dot != null) ...<Widget>[
            Container(
              key: const ValueKey<String>('app_pill.dot'),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _dotColor(dot!, _variant),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...<Widget>[
            Icon(icon, size: _iconSize, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTokens.fontSans,
              fontSize: AppTokens.captionSize,
              height: AppTokens.captionLineHeight / AppTokens.captionSize,
              fontWeight: AppTokens.captionWeight,
              color: colors.foreground,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );

    // El dot comunica estado solo por color; un único nodo semántico combina
    // el label visible con el estado verbalizado ("Etiqueta, Activo") para que
    // el lector anuncie ambos. ExcludeSemantics descarta el nodo del Text
    // interno para que la etiqueta del nodo sea exactamente la combinada.
    if (dot != null) {
      return Semantics(
        container: true,
        label: '$label, ${_dotSemanticLabel(dot!)}',
        child: ExcludeSemantics(child: pill),
      );
    }
    return pill;
  }

  static _AppPillColors _colorsFor(_AppPillVariant variant) {
    switch (variant) {
      // Pill rellena de marca: fill amarillo pleno con texto oscuro
      // (regla on-primary — el amarillo exige primer plano oscuro).
      case _AppPillVariant.primary:
        return const _AppPillColors(
          background: AppTokens.primary,
          foreground: AppTokens.onPrimary,
        );
      case _AppPillVariant.neutral:
        return const _AppPillColors(
          background: AppTokens.surface3,
          foreground: AppTokens.text2,
        );
      case _AppPillVariant.danger:
        return _AppPillColors(
          background: AppTokens.danger.withValues(alpha: 0.16),
          foreground: AppTokens.danger,
        );
      case _AppPillVariant.outline:
        return _AppPillColors(
          background: Colors.transparent,
          foreground: AppTokens.text2,
          border: Border.all(color: AppTokens.divider),
        );
      // Velo oscuro translúcido sobre el fill cálido: el primer plano oscuro
      // (onPrimary) lee sobre el ámbar y la cápsula sólo agrupa/separa.
      case _AppPillVariant.glass:
        return _AppPillColors(
          background: AppTokens.onPrimary.withValues(alpha: 0.16),
          foreground: AppTokens.onPrimary,
        );
    }
  }

  static Color _dotColor(AppPillDot dot, _AppPillVariant variant) {
    // Sobre el fill amarillo de la variante primary el dot exige primer plano
    // oscuro (onPrimary) para ser visible; un dot cálido se perdería.
    if (variant == _AppPillVariant.primary) {
      return AppTokens.onPrimary;
    }
    // En la cápsula glass (sobre el gradiente) los dots cálidos se perderían:
    // activo = onPrimary sólido, pausado = el mismo atenuado.
    if (variant == _AppPillVariant.glass) {
      switch (dot) {
        case AppPillDot.active:
          return AppTokens.onPrimary;
        case AppPillDot.paused:
          return AppTokens.onPrimary.withValues(alpha: 0.45);
        case AppPillDot.danger:
          return AppTokens.danger;
      }
    }
    switch (dot) {
      // Verde de éxito, no el accent de marca: "encendido" comunica salud y
      // el cálido, repetido en cada fila sana, leería como alerta permanente.
      case AppPillDot.active:
        return AppTokens.success;
      case AppPillDot.paused:
        return AppTokens.text2;
      case AppPillDot.danger:
        return AppTokens.danger;
    }
  }

  static String _dotSemanticLabel(AppPillDot dot) {
    switch (dot) {
      case AppPillDot.active:
        return 'Activo';
      case AppPillDot.paused:
        return 'Pausado';
      case AppPillDot.danger:
        return 'Error';
    }
  }
}

class _AppPillColors {
  const _AppPillColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final BoxBorder? border;
}
