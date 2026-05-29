import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/connect_link.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_connect_bloc.dart';

/// Pantalla "compartir enlace de conexión" (S04). Content-only: el Scaffold y
/// el AppBar los aporta la ruta `/bots/:id/connect`.
///
/// Flujo de dos tiempos (ver [BotConnectBloc]): primero se comparte el enlace
/// (vive 15 min); luego, cuando la otra persona está por escanear, el operador
/// inicia el emparejamiento (el QR vive ~2 min). Por eso "Iniciar
/// emparejamiento" es una acción aparte y no ocurre al abrir la pantalla.
class BotConnectPage extends StatelessWidget {
  const BotConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotConnectBloc, BotConnectState>(
      builder: (context, state) => switch (state) {
        BotConnectLoading() => const _LoadingView(),
        BotConnectReady(link: final link, phase: final phase) => _ReadyView(
          link: link,
          phase: phase,
        ),
        BotConnectFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.link, required this.phase});

  final ConnectLink link;
  final PairingPhase phase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.sp6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Comparte este enlace', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Quien lo abra verá el código QR para vincular este bot desde '
            'WhatsApp. No necesita una cuenta.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp6),
          AppCard(
            child: SelectableText(
              link.url,
              key: const Key('bot_connect.url'),
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppTokens.sp3),
          AppButton.filled(
            label: 'Copiar enlace',
            fullWidth: true,
            onPressed: () => _copy(context),
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Caduca a las ${_hhmm(link.expiresAt.toLocal())}.',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp7),
          const Divider(color: AppTokens.divider, height: 1),
          const SizedBox(height: AppTokens.sp6),
          _PairingSection(phase: phase),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: link.url));
    messenger.showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  /// Formato HH:mm sin depender de intl. La fecha llega del backend en UTC;
  /// el caller la pasa ya en hora local.
  static String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Bloque de "encender el QR". Separado del enlace porque el código vive sólo
/// ~2 min: se inicia cuando la otra persona ya tiene el enlace abierto.
class _PairingSection extends StatelessWidget {
  const _PairingSection({required this.phase});

  final PairingPhase phase;

  void _start(BuildContext context) =>
      context.read<BotConnectBloc>().add(const BotConnectPairingRequested());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    switch (phase) {
      case PairingPhase.idle:
      case PairingPhase.starting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Cuando la otra persona tenga el enlace abierto y lista para '
              'escanear, inicia el emparejamiento. El QR queda activo ~2 min.',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              label: 'Iniciar emparejamiento',
              fullWidth: true,
              loading: phase == PairingPhase.starting,
              onPressed: () => _start(context),
            ),
          ],
        );
      case PairingPhase.active:
        return AppCard(
          key: const Key('bot_connect.active'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.qr_code_2,
                    color: AppTokens.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppTokens.sp2),
                  Expanded(
                    child: Text(
                      'Emparejamiento activo',
                      style: textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'Pide que escaneen el QR ahora — válido ~2 minutos. Si expira, '
                'vuelve a iniciarlo.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp4),
              AppButton.tonal(
                label: 'Reiniciar emparejamiento',
                fullWidth: true,
                onPressed: () => _start(context),
              ),
            ],
          ),
        );
      case PairingPhase.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'No se pudo iniciar el emparejamiento.',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              label: 'Reintentar',
              fullWidth: true,
              onPressed: () => _start(context),
            ),
          ],
        );
    }
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('bot_connect.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _message(failure),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () =>
                  context.read<BotConnectBloc>().add(const BotConnectStarted()),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(BotsFailure f) => switch (f) {
    BotsForbiddenFailure() => 'No tienes permiso para conectar este bot.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e intenta de nuevo.',
    _ => 'No pudimos preparar el enlace de conexión.',
  };
}
