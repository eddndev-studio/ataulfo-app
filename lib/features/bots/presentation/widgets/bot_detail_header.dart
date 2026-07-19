import 'package:flutter/material.dart';

import '../../../../core/design/widgets/app_detail_header.dart';
import '../../../../core/design/widgets/app_pill.dart';

/// Header rico del detalle de un bot: una tarjeta full-bleed con el gradiente
/// de marca VERTICAL (ámbar arriba → naranja abajo) soldada al borde superior
/// —solo las esquinas inferiores son redondeadas— que reemplaza al AppBar de la
/// ruta. Reusa el lenguaje del [AppHeaderCard] de sección: fill cálido, con la
/// identidad y los metadatos en color invertido (oscuro sobre el ámbar) para
/// resaltar sobre el gradiente.
///
/// La tarjeta concentra la identidad y el estado del bot: nombre, canal y, en
/// cápsulas glass, la versión (CAS), si está activo o pausado, si la IA está
/// deshabilitada y el identificador. Como la ruta ya no monta AppBar, el header
/// aporta su propio retorno; para ADMIN+ ofrece además el acceso a editar. Es
/// full-bleed: el consumidor lo monta SIN el padding lateral del layout (el
/// padding interno lo pone la tarjeta) y reserva el inset de status bar para que
/// el contenido no quede bajo el notch al ir sin AppBar.
class BotDetailHeader extends StatelessWidget {
  const BotDetailHeader({
    super.key,
    required this.name,
    required this.channelLabel,
    required this.version,
    required this.paused,
    required this.aiDisabled,
    required this.identifier,
    required this.onBack,
    this.showEdit = false,
    this.onEdit,
  });

  final String name;
  final String channelLabel;

  /// Versión CAS del bot; el operador la lee para sospechar colisiones.
  final int version;
  final bool paused;
  final bool aiDisabled;

  /// Identificador del canal (p.ej. el número de WhatsApp). Null/vacío ⇒ no se
  /// muestra la cápsula.
  final String? identifier;

  final VoidCallback onBack;

  /// ADMIN+ ve el lápiz de edición; WORKER no.
  final bool showEdit;

  /// Acción de editar. `null` lo deja inerte (p.ej. durante un PUT en vuelo)
  /// sin ocultarlo, igual que el resto de controles de mutación.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AppDetailHeader(
      title: name,
      subtitle: channelLabel,
      onBack: onBack,
      backKey: const Key('bot_detail.back'),
      showEdit: showEdit,
      onEdit: showEdit ? onEdit : null,
      editKey: const Key('bot_detail.edit'),
      editTooltip: 'Editar canal',
      metadata: <Widget>[
        AppPill.glass(label: 'v$version'),
        if (paused)
          const AppPill.glass(label: 'Pausado', dot: AppPillDot.paused)
        else
          const AppPill.glass(label: 'Activo', dot: AppPillDot.active),
        if (aiDisabled)
          const AppPill.glass(
            label: 'IA deshabilitada',
            dot: AppPillDot.paused,
          ),
        if (identifier != null && identifier!.trim().isNotEmpty)
          AppPill.glass(label: identifier!.trim()),
      ],
    );
  }
}
