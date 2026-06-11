import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/bot.dart';
import '../../domain/entities/session_status.dart';
import '../bloc/bot_session_status_bloc.dart';

/// Card hero del hub del bot: el estado VIVO de la sesión de canal — lo
/// primero que un operador necesita saber ("¿está en línea?") sin tener que
/// entrar a la pantalla de conexión. Consume el [BotSessionStatusBloc] del
/// scope (poll de la ruta) y ofrece el CTA contextual hacia `/connect`.
///
/// Honestidad del dato: si el estado no se pudo consultar (rol sin acceso,
/// red caída) la card lo dice tal cual y deja el CTA intacto — nunca pinta
/// un "sin conexión" que no consta.
class BotConnectionCard extends StatelessWidget {
  const BotConnectionCard({super.key, required this.bot});

  final Bot bot;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotSessionStatusBloc, BotSessionStatusState>(
      builder: (context, state) {
        final view = _viewFor(state);
        return AppCard(
          key: const Key('bot_detail.connection'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _StatusGlyph(view: view),
                  const SizedBox(width: AppTokens.sp4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          view.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          view.caption,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTokens.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp4),
              _cta(context, view),
            ],
          ),
        );
      },
    );
  }

  Widget _cta(BuildContext context, _ConnectionView view) {
    void open() =>
        context.push('/bots/${bot.id}/connect?channel=${bot.channel.toWire()}');
    const key = Key('bot_detail.connection.cta');
    // Conectado: gestionar es acción secundaria (tonal). En cualquier otro
    // estado conectar ES la tarea pendiente → primaria (filled).
    return view.connected
        ? AppButton.tonal(
            key: key,
            label: view.ctaLabel,
            fullWidth: true,
            onPressed: open,
          )
        : AppButton.filled(
            key: key,
            label: view.ctaLabel,
            fullWidth: true,
            onPressed: open,
          );
  }

  static _ConnectionView _viewFor(BotSessionStatusState state) =>
      switch (state) {
        BotSessionStatusLoading() => const _ConnectionView(
          title: 'Conexión',
          caption: 'Comprobando el estado de la sesión…',
          icon: Icons.qr_code_2,
          color: AppTokens.text2,
          ctaLabel: 'Conectar WhatsApp',
          loading: true,
        ),
        BotSessionStatusFailed() => const _ConnectionView(
          title: 'Estado no disponible',
          caption: 'No pudimos consultar la sesión; puedes conectar igual.',
          icon: Icons.help_outline,
          color: AppTokens.text2,
          ctaLabel: 'Conectar WhatsApp',
        ),
        BotSessionStatusLoaded(status: final s) => switch (s.state) {
          SessionState.connected => const _ConnectionView(
            title: 'En línea',
            caption: 'WhatsApp está vinculado y el bot opera.',
            icon: Icons.check_circle,
            color: AppTokens.success,
            ctaLabel: 'Gestionar conexión',
            connected: true,
          ),
          SessionState.pairing => const _ConnectionView(
            title: 'Emparejando…',
            caption: 'Hay un código QR activo; escanéalo desde WhatsApp.',
            icon: Icons.qr_code_2,
            color: AppTokens.primary,
            ctaLabel: 'Abrir emparejamiento',
          ),
          SessionState.connecting => const _ConnectionView(
            title: 'Conectando…',
            caption: 'Estableciendo la conexión con WhatsApp.',
            icon: Icons.sync,
            color: AppTokens.warning,
            ctaLabel: 'Gestionar conexión',
          ),
          SessionState.reconnecting => const _ConnectionView(
            title: 'Reconectando…',
            caption: 'Recuperando la conexión con WhatsApp.',
            icon: Icons.sync,
            color: AppTokens.warning,
            ctaLabel: 'Gestionar conexión',
          ),
          SessionState.disconnected => const _ConnectionView(
            title: 'Sin conexión',
            caption: 'Vincula WhatsApp para que el bot reciba mensajes.',
            icon: Icons.link_off,
            color: AppTokens.danger,
            ctaLabel: 'Conectar WhatsApp',
          ),
        },
      };
}

/// Proyección de presentación de un estado de sesión: copy + glifo + CTA.
class _ConnectionView {
  const _ConnectionView({
    required this.title,
    required this.caption,
    required this.icon,
    required this.color,
    required this.ctaLabel,
    this.connected = false,
    this.loading = false,
  });

  final String title;
  final String caption;
  final IconData icon;
  final Color color;
  final String ctaLabel;
  final bool connected;
  final bool loading;
}

/// Tile circular 44px (paridad con AppEntityIcon) con el glifo del estado en
/// su color semántico; en carga, un spinner pequeño en su lugar.
class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.view});

  final _ConnectionView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppTokens.surface3,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: view.loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
              ),
            )
          : Icon(view.icon, size: 22, color: view.color),
    );
  }
}
