import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/failures/flow_run_failure.dart';
import '../../domain/repositories/flow_run_repository.dart';
import '../bloc/flow_run_cubit.dart';

/// Hoja inferior para correr un flujo sobre el chat abierto (S11). Lista los
/// flujos ACTIVOS del bot (WORKER+); tocar uno lo arranca y cierra la hoja con
/// un SnackBar del desenlace (iniciado / bloqueado por gate / error). El
/// progreso de la Execution se ve en el monitor de ejecuciones, no aquí.
///
/// Crea su propio `FlowRunCubit` leyendo el `FlowRunRepository` del scope (lo
/// provee la ruta del hilo). `botId`/`chatLid` los aporta el app bar.
class FlowRunSheet extends StatefulWidget {
  const FlowRunSheet({super.key, required this.chatLid});

  final String chatLid;

  static void open(
    BuildContext context, {
    required String botId,
    required String chatLid,
  }) {
    final repo = context.read<FlowRunRepository>();
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<FlowRunCubit>(
        create: (_) => FlowRunCubit(repo: repo, botId: botId)..load(),
        child: FlowRunSheet(chatLid: chatLid),
      ),
    );
  }

  @override
  State<FlowRunSheet> createState() => _FlowRunSheetState();
}

class _FlowRunSheetState extends State<FlowRunSheet> {
  bool _running = false;

  Future<void> _run(String flowId) async {
    if (_running) {
      return;
    }
    setState(() => _running = true);
    final cubit = context.read<FlowRunCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final outcome = await cubit.run(chatLid: widget.chatLid, flowId: flowId);
    if (!mounted) {
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(_outcomeText(outcome))));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.safeBottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp4,
                AppTokens.sp2,
              ),
              child: Text('Correr un flujo', style: textTheme.titleMedium),
            ),
            BlocBuilder<FlowRunCubit, FlowRunState>(
              builder: (context, state) => switch (state) {
                FlowRunInitial() || FlowRunLoading() => const Padding(
                  key: Key('flow_run.loading'),
                  padding: EdgeInsets.all(AppTokens.sp6),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTokens.primary,
                      ),
                    ),
                  ),
                ),
                FlowRunLoaded(flows: final flows) =>
                  flows.isEmpty
                      ? Padding(
                          key: const Key('flow_run.empty'),
                          padding: const EdgeInsets.all(AppTokens.sp6),
                          child: Text(
                            'Este bot no tiene flujos activos',
                            style: textTheme.bodyLarge,
                          ),
                        )
                      : Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: <Widget>[
                              for (final f in flows)
                                ListTile(
                                  key: Key('flow_run.item.${f.id}'),
                                  enabled: !_running,
                                  leading: const Icon(
                                    Icons.play_circle_outline,
                                    color: AppTokens.primary,
                                  ),
                                  title: Text(f.name),
                                  onTap: () => _run(f.id),
                                ),
                            ],
                          ),
                        ),
                FlowRunFailed(failure: final f) => Padding(
                  key: const Key('flow_run.error'),
                  padding: const EdgeInsets.all(AppTokens.sp6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_errorText(f), style: textTheme.bodyLarge),
                      // Reintentar sólo para fallos transitorios; un 403 /
                      // not-found / bot pausado devolvería lo mismo.
                      if (_isTransient(f)) ...<Widget>[
                        const SizedBox(height: AppTokens.sp3),
                        Builder(
                          builder: (context) => AppButton.tonal(
                            label: 'Reintentar',
                            onPressed: () =>
                                context.read<FlowRunCubit>().load(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _outcomeText(RunOutcome o) => switch (o) {
  RunStarted() => 'Flujo iniciado',
  RunBlocked(reason: final r) => 'No se inició: ${_reasonText(r)}',
  RunError(failure: final f) => _errorText(f),
};

String _reasonText(String reason) => switch (reason) {
  'COOLDOWN' => 'el flujo está en enfriamiento',
  'LIMIT' => 'el flujo alcanzó su límite de usos',
  'EXCLUDED' => 'otro flujo excluyente está activo',
  _ => 'una regla del flujo lo bloqueó',
};

/// Fallos donde reintentar tiene sentido (red/timeout/server/desconocido);
/// los terminales (paused/forbidden/not-found) devolverían lo mismo.
bool _isTransient(FlowRunFailure f) =>
    f is FlowRunNetworkFailure ||
    f is FlowRunTimeoutFailure ||
    f is FlowRunServerFailure ||
    f is UnknownFlowRunFailure;

String _errorText(FlowRunFailure f) => switch (f) {
  FlowRunPausedFailure() => 'El bot está pausado',
  FlowRunNotFoundFailure() => 'El flujo ya no está disponible',
  FlowRunForbiddenFailure() => 'No tienes permiso para correr flujos',
  FlowRunNetworkFailure() || FlowRunTimeoutFailure() => 'Sin conexión',
  _ => 'No se pudo iniciar el flujo',
};
