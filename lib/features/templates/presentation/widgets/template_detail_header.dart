import 'package:flutter/material.dart';

import '../../../../core/design/widgets/app_detail_header.dart';
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

  @override
  Widget build(BuildContext context) {
    return AppDetailHeader(
      title: name,
      subtitle: providerModelLabel,
      onBack: onBack,
      backKey: const Key('template_detail.back'),
      onEdit: onEdit,
      editKey: const Key('template_detail.edit_button'),
      editTooltip: 'Editar Asistente',
      metadata: <Widget>[
        AppPill.glass(label: 'v$version'),
        if (aiEnabled)
          const AppPill.glass(label: 'IA habilitada', dot: AppPillDot.active)
        else
          const AppPill.glass(
            label: 'IA deshabilitada',
            dot: AppPillDot.paused,
          ),
      ],
    );
  }
}
