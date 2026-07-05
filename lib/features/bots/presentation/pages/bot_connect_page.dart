import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_danger_zone.dart';
import '../../domain/entities/bot.dart';
import '../../domain/entities/connect_link.dart';
import '../../domain/entities/session_status.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_connect_bloc.dart';

/// Pantalla "compartir enlace de conexión" (S04). Content-only: el Scaffold y
/// el AppBar los aporta la ruta `/bots/:id/connect`.
///
/// Flujo de dos tiempos (ver [BotConnectBloc]): primero se comparte el enlace
/// (vive 15 min); luego, cuando la otra persona está por escanear, el operador
/// inicia el emparejamiento (el QR vive ~2 min). Por eso "Iniciar
/// emparejamiento" es una acción aparte y no ocurre al abrir la pantalla.
///
/// El `channel` (default `WA_UNOFFICIAL`, el único hoy) gatea la sección de
/// borrar credenciales: el wipe sólo aplica a WA no oficial; en WABA se oculta.
class BotConnectPage extends StatelessWidget {
  const BotConnectPage({super.key, this.channel = BotChannel.waUnofficial});

  final BotChannel channel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotConnectBloc, BotConnectState>(
      builder: (context, state) => switch (state) {
        BotConnectLoading() => const _LoadingView(),
        BotConnectReady(
          link: final link,
          phase: final phase,
          status: final status,
          qrExpired: final qrExpired,
        ) =>
          _ReadyView(
            link: link,
            phase: phase,
            channel: channel,
            status: status,
            qrExpired: qrExpired,
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
  const _ReadyView({
    required this.link,
    required this.phase,
    required this.channel,
    required this.status,
    required this.qrExpired,
  });

  final ConnectLink link;
  final PairingPhase phase;
  final BotChannel channel;
  final SessionStatus? status;
  final bool qrExpired;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
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
          _PairingSection(phase: phase, status: status, qrExpired: qrExpired),
          // Wipe (Tier B): SÓLO WA no oficial; oculto en WABA. No gateado por
          // paused; siempre disponible tras confirmación fuerte.
          if (channel == BotChannel.waUnofficial) ...<Widget>[
            const SizedBox(height: AppTokens.sp7),
            AppDangerZone(
              caption:
                  'Borrar las credenciales del dispositivo desvincula el bot: '
                  're-parea desde cero (nuevo QR). Úsalo si la sesión quedó '
                  'corrupta o quieres mover el bot a otro número.',
              actions: <Widget>[
                AppButton.danger(
                  key: const Key('bot_connect.wipe'),
                  label: 'Borrar credenciales del dispositivo',
                  fullWidth: true,
                  onPressed: () => _confirmWipe(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context) async {
    // Capturado antes del await: el diálogo desmonta/remonta contextos.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Borrar credenciales del dispositivo?',
      message:
          'El bot perderá su vínculo con WhatsApp y deberá re-parearse desde '
          'cero (nuevo QR). Esta acción no se puede deshacer.',
      confirmLabel: 'Borrar',
      confirmKey: const Key('bot_connect.wipe_confirm'),
    );
    if (!confirmed || !context.mounted) return;
    context.read<BotConnectBloc>().add(const BotConnectWipeRequested());
    // El bloc trata el wipe como siempre-éxito (idempotente, sin estado
    // propio): este aviso es el único feedback de que la acción se registró.
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Credenciales borradas. Inicia el emparejamiento para volver a '
          'vincular.',
        ),
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
///
/// Cuando el poll trae el estado REAL ([status]) toma precedencia sobre la
/// [phase] optimista: CONNECTED → "En línea"; PAIRING con código → QR
/// escaneable; expiración del QR → aviso + re-ofrecer Iniciar.
class _PairingSection extends StatelessWidget {
  const _PairingSection({
    required this.phase,
    required this.status,
    required this.qrExpired,
  });

  final PairingPhase phase;
  final SessionStatus? status;
  final bool qrExpired;

  void _start(BuildContext context) =>
      context.read<BotConnectBloc>().add(const BotConnectPairingRequested());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // 1) Estado real del backend (poll) — toma precedencia sobre la fase.
    final st = status?.state;
    if (st == SessionState.connected) {
      return AppCard(
        key: const Key('bot_connect.connected'),
        child: Row(
          children: <Widget>[
            const Icon(Icons.check_circle, color: AppTokens.success, size: 20),
            const SizedBox(width: AppTokens.sp2),
            Expanded(child: Text('Bot en línea', style: textTheme.titleMedium)),
          ],
        ),
      );
    }
    final qr = status?.qrCode;
    if (st == SessionState.pairing && qr != null && qr.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Escanea este código', style: textTheme.titleMedium),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Desde WhatsApp › Dispositivos vinculados › Vincular dispositivo. '
            'Válido ~2 minutos.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp4),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppTokens.sp3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: QrImageView(
                key: const Key('bot_connect.qr'),
                data: qr,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.danger(
            key: const Key('bot_connect.stop'),
            label: 'Cancelar emparejamiento',
            fullWidth: true,
            onPressed: () => context.read<BotConnectBloc>().add(
              const BotConnectStopRequested(),
            ),
          ),
        ],
      );
    }
    if (qrExpired) {
      return Column(
        key: const Key('bot_connect.qr_expired'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'El código QR expiró (~2 min). Pulsa Iniciar para generar uno '
            'nuevo cuando la otra persona esté lista para escanear.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.filled(
            label: 'Iniciar emparejamiento',
            fullWidth: true,
            onPressed: () => _start(context),
          ),
        ],
      );
    }

    // 2) Sin estado real aún: la fase optimista de arranque.
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
              // En esta fase el QR aún no llegó (con qrCode el bloque del QR
              // escaneable toma precedencia): comunicar la espera real en vez
              // de pedir escanear algo que no está en pantalla.
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.sp2),
                  Expanded(
                    child: Text(
                      'Generando el código QR…',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp4),
              AppButton.tonal(
                label: 'Reiniciar emparejamiento',
                fullWidth: true,
                onPressed: () => _start(context),
              ),
              const SizedBox(height: AppTokens.sp2),
              AppButton.danger(
                key: const Key('bot_connect.stop'),
                label: 'Cancelar emparejamiento',
                fullWidth: true,
                onPressed: () => context.read<BotConnectBloc>().add(
                  const BotConnectStopRequested(),
                ),
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
