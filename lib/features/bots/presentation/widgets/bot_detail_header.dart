import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
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

  /// Gradiente de marca VERTICAL, idéntico al del header de sección. No reusa
  /// `brandGradient` (diagonal) a propósito.
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
              // Solo la flecha de volver (oscura, sin botón circular). La
              // ruta ya no monta AppBar.
              IconButton(
                key: const Key('bot_detail.back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: AppTokens.onPrimary,
                tooltip: 'Volver',
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(height: AppTokens.sp3),
              // Nombre + proveedor a la izquierda; el lápiz de editar (ADMIN)
              // comparte su fila. Sin avatar: un bot no es una persona.
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
                          // Mismo estilo que el título de sección
                          // (AppHeaderCard) en Bots/Plantillas, para
                          // congruencia entre pantallas.
                          style: AppTokens.heroTitle.copyWith(
                            color: AppTokens.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          channelLabel,
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
                  if (showEdit)
                    IconButton(
                      key: const Key('bot_detail.edit'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      color: AppTokens.onPrimary,
                      tooltip: 'Editar canal',
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.sp4),
              // Metadatos del bot EN la tarjeta, en cápsulas glass (leen
              // sobre el gradiente): versión, estado, IA e identificador.
              Wrap(
                spacing: AppTokens.sp2,
                runSpacing: AppTokens.sp2,
                children: <Widget>[
                  AppPill.glass(label: 'v$version'),
                  if (paused)
                    const AppPill.glass(
                      label: 'Pausado',
                      dot: AppPillDot.paused,
                    )
                  else
                    const AppPill.glass(
                      label: 'Activo',
                      dot: AppPillDot.active,
                    ),
                  if (aiDisabled)
                    const AppPill.glass(
                      label: 'IA deshabilitada',
                      dot: AppPillDot.paused,
                    ),
                  if (identifier != null && identifier!.trim().isNotEmpty)
                    AppPill.glass(label: identifier!.trim()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
