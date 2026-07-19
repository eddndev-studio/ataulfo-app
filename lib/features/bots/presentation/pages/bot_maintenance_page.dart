import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_danger_zone.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_maintenance_bloc.dart';

/// Zona Peligrosa Tier A de un Bot (S04), sub-página `/bots/:id/maintenance`.
/// Aloja las dos ops de runtime que EXIGEN `paused=true`: borrar conversaciones
/// y reiniciar sesiones de cifrado. Content-only: Scaffold/AppBar de la ruta.
///
/// El gateo por `paused` es de la UI (botones inhabilitados si `!paused`); el
/// switch de pausa es el desbloqueo. El bot NO se reanuda solo — se recuerda
/// explícitamente.
class BotMaintenancePage extends StatelessWidget {
  const BotMaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BotMaintenanceBloc, BotMaintenanceState>(
      listenWhen: (_, current) => current is BotMaintenanceOpSucceeded,
      listener: (context, state) {
        if (state is! BotMaintenanceOpSucceeded) return;
        final msg = switch (state.op) {
          MaintenanceOp.clear => 'Conversaciones borradas.',
          MaintenanceOp.reset => 'Sesiones de cifrado reiniciadas.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      },
      child: BlocBuilder<BotMaintenanceBloc, BotMaintenanceState>(
        builder: (context, state) => switch (state) {
          BotMaintenanceLoading() => const _LoadingView(),
          BotMaintenanceFailed(failure: final f) => _FailedView(failure: f),
          BotMaintenanceLoaded(bot: final bot) => _Body(bot: bot),
          BotMaintenanceBusy(bot: final bot) => _Body(bot: bot, busy: true),
          BotMaintenanceOpSucceeded(bot: final bot) => _Body(bot: bot),
          BotMaintenanceOpFailed(bot: final bot, failure: final f) => _Body(
            bot: bot,
            failure: f,
          ),
        },
      ),
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

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar el mantenimiento del Canal.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<BotMaintenanceBloc>().add(
                const BotMaintenanceLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.bot, this.busy = false, this.failure});

  final Bot bot;
  final bool busy;
  final BotsFailure? failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final f = failure;
    final canRun = bot.paused && !busy;
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
          if (!bot.paused)
            AppCard(
              child: Text(
                'Estas operaciones requieren pausar el Canal primero. Pausa para '
                'habilitarlas; el Canal NO se reanuda solo, reanúdalo al terminar.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            )
          else
            AppCard(
              child: Text(
                'El Canal está pausado. El Canal NO se reanuda solo: reanúdalo con '
                'el interruptor cuando termines.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            ),
          const SizedBox(height: AppTokens.sp5),
          AppToggleRow(
            switchKey: const Key('bot_maint.pause'),
            label: bot.paused ? 'Reanudar Canal' : 'Pausar Canal',
            caption: bot.paused
                ? 'Reanuda el procesamiento de mensajes.'
                : 'Pausar habilita las operaciones de abajo.',
            value: bot.paused,
            onChanged: busy
                ? null
                : (_) => context.read<BotMaintenanceBloc>().add(
                    const BotMaintenancePauseToggled(),
                  ),
          ),
          if (f != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            Text(
              _failureMessage(f),
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
          ],
          const SizedBox(height: AppTokens.sp7),
          AppDangerZone(
            caption:
                'Estas operaciones alteran datos reales del Canal y no se '
                'pueden deshacer. Exigen el Canal pausado.',
            actions: <Widget>[
              AppButton.danger(
                key: const Key('bot_maint.clear'),
                label: 'Borrar conversaciones',
                fullWidth: true,
                onPressed: canRun
                    ? () => _confirm(
                        context,
                        title: '¿Borrar conversaciones?',
                        body:
                            'Se eliminarán mensajes, sesiones, ejecuciones y '
                            'etiquetas de chat de este Canal. No se puede '
                            'deshacer.',
                        confirmKey: const Key('bot_maint.clear_confirm'),
                        onConfirm: () => context.read<BotMaintenanceBloc>().add(
                          const BotMaintenanceClearRequested(),
                        ),
                      )
                    : null,
              ),
              AppButton.danger(
                key: const Key('bot_maint.reset'),
                label: 'Reiniciar sesiones de cifrado',
                fullWidth: true,
                onPressed: canRun
                    ? () => _confirm(
                        context,
                        title: '¿Reiniciar sesiones de cifrado?',
                        body:
                            'Invalida el handshake Signal de las '
                            'conversaciones (útil tras errores "Bad MAC"). '
                            'El pareado se conserva.',
                        confirmKey: const Key('bot_maint.reset_confirm'),
                        onConfirm: () => context.read<BotMaintenanceBloc>().add(
                          const BotMaintenanceResetRequested(),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required Key confirmKey,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: title,
      message: body,
      confirmLabel: 'Continuar',
      confirmKey: confirmKey,
    );
    if (confirmed) onConfirm();
  }

  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsNotPausedFailure() =>
      'El Canal no está pausado. Refresca y pausa antes de continuar.',
    BotsConflictFailure() =>
      'El Canal cambió mientras operabas. Refresca e inténtalo de nuevo.',
    BotsForbiddenFailure() => 'Tu rol no permite esta operación.',
    BotsNotFoundFailure() => 'Este Canal ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsInvalidCreateFailure() ||
    BotsPairingNotStartedFailure() ||
    BotsPhoneRejectedFailure() ||
    BotsServerFailure() ||
    UnknownBotsFailure() =>
      'No pudimos completar la operación. Inténtalo de nuevo.',
  };
}
