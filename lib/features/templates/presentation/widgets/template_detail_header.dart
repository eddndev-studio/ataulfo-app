import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_pill.dart';

/// Header rico del detalle de una plantilla: tarjeta full-bleed con el
/// gradiente de marca VERTICAL (ámbar arriba → naranja abajo) soldada al borde
/// superior —solo las esquinas inferiores son redondeadas— que reemplaza al
/// AppBar de la ruta. Mismo lenguaje que el header del detalle de bot: la
/// identidad y los metadatos en color invertido (oscuro sobre el ámbar).
///
/// Concentra identidad y configuración visible de la plantilla: nombre,
/// proveedor · modelo, y en cápsulas glass la versión (CAS) y el estado de la
/// IA. Aporta su propio retorno (la ruta ya no monta AppBar) y el lápiz de
/// editar. Es full-bleed: el consumidor lo monta SIN el padding lateral del
/// layout y el padding superior reserva el inset de status bar.
class TemplateDetailHeader extends StatelessWidget {
  const TemplateDetailHeader({
    super.key,
    required this.name,
    required this.providerModelLabel,
    required this.version,
    required this.aiEnabled,
    required this.onBack,
    required this.onEdit,
  });

  final String name;

  /// Línea "Proveedor · modelo" (p. ej. "Gemini · gemini-3.1-pro-preview").
  final String providerModelLabel;

  /// Versión CAS de la plantilla.
  final int version;
  final bool aiEnabled;

  final VoidCallback onBack;
  final VoidCallback onEdit;

  /// Gradiente de marca VERTICAL, idéntico al del header de sección y al del
  /// detalle de bot. No reusa `brandGradient` (diagonal) a propósito.
  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppTokens.primary, AppTokens.accent],
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _gradient),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp5,
            topInset + AppTokens.sp4,
            AppTokens.sp5,
            AppTokens.sp6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: const Key('template_detail.back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: AppTokens.onPrimary,
                tooltip: 'Volver',
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(height: AppTokens.sp3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          // Mismo estilo que los títulos de AppHeaderCard y
                          // BotDetailHeader, para congruencia entre pantallas.
                          style: const TextStyle(
                            fontFamily: AppTokens.fontSans,
                            fontSize: 34,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          providerModelLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTokens.fontSans,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTokens.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('template_detail.edit_button'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    color: AppTokens.onPrimary,
                    tooltip: 'Editar plantilla',
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp4),
              Wrap(
                spacing: AppTokens.sp2,
                runSpacing: AppTokens.sp2,
                children: <Widget>[
                  AppPill.glass(label: 'v$version'),
                  if (aiEnabled)
                    const AppPill.glass(
                      label: 'IA habilitada',
                      dot: AppPillDot.active,
                    )
                  else
                    const AppPill.glass(
                      label: 'IA deshabilitada',
                      dot: AppPillDot.paused,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
