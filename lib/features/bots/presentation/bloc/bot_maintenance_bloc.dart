import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bot_session_repository.dart';
import '../../domain/repositories/bots_repository.dart';

/// Operación destructiva de runtime de la Zona Peligrosa Tier A.
enum MaintenanceOp { clear, reset }

/// Bloc de la Zona Peligrosa Tier A de un Bot (S04), página separada
/// (`/bots/:id/maintenance`). Aloja las dos ops que EXIGEN `paused=true`:
/// `clear-conversations` (purga messages/sessions/executions) y
/// `reset-sessions` (invalida el handshake Signal sin perder el pareado).
///
/// Cross-feature: `BotsRepository` para leer/togglear `paused` (el desbloqueo)
/// y `BotSessionRepository` para las ops. El gateo por `paused` lo enforça la
/// UI (botones inhabilitados si `!paused`); el 409 `ErrBotNotPaused` →
/// `BotsNotPausedFailure` es la red de seguridad si el estado quedó stale.
class BotMaintenanceBloc
    extends Bloc<BotMaintenanceEvent, BotMaintenanceState> {
  BotMaintenanceBloc({
    required BotsRepository botsRepo,
    required BotSessionRepository sessionRepo,
    required String botId,
  }) : _botsRepo = botsRepo,
       _sessionRepo = sessionRepo,
       _botId = botId,
       super(const BotMaintenanceLoading()) {
    on<BotMaintenanceLoadRequested>(_onLoad);
    on<BotMaintenancePauseToggled>(_onPauseToggled);
    on<BotMaintenanceClearRequested>(_onClear);
    on<BotMaintenanceResetRequested>(_onReset);
  }

  final BotsRepository _botsRepo;
  final BotSessionRepository _sessionRepo;
  final String _botId;

  Future<void> _onLoad(
    BotMaintenanceLoadRequested event,
    Emitter<BotMaintenanceState> emit,
  ) async {
    if (state is! BotMaintenanceLoading) {
      emit(const BotMaintenanceLoading());
    }
    try {
      final bot = await _botsRepo.byId(_botId);
      emit(BotMaintenanceLoaded(bot));
    } on BotsFailure catch (f) {
      emit(BotMaintenanceFailed(f));
    }
  }

  Future<void> _onPauseToggled(
    BotMaintenancePauseToggled event,
    Emitter<BotMaintenanceState> emit,
  ) async {
    final snapshot = _snapshot();
    if (snapshot == null) return;
    emit(BotMaintenanceBusy(snapshot));
    try {
      final updated = await _botsRepo.update(
        id: _botId,
        version: snapshot.version,
        paused: !snapshot.paused,
      );
      emit(BotMaintenanceLoaded(updated));
    } on BotsFailure catch (f) {
      emit(BotMaintenanceOpFailed(snapshot, f));
    }
  }

  Future<void> _onClear(
    BotMaintenanceClearRequested event,
    Emitter<BotMaintenanceState> emit,
  ) => _runOp(emit, MaintenanceOp.clear, _sessionRepo.clearConversations);

  Future<void> _onReset(
    BotMaintenanceResetRequested event,
    Emitter<BotMaintenanceState> emit,
  ) => _runOp(emit, MaintenanceOp.reset, _sessionRepo.resetSessions);

  /// Ejecuta una op destructiva (clear/reset) sobre el snapshot vigente. El
  /// bot no cambia (paused sigue igual), así que el éxito vuelve al mismo
  /// snapshot tras un `OpSucceeded` transitorio (que la UI usa para confirmar).
  /// 409 `ErrBotNotPaused` → `OpFailed(BotsNotPausedFailure)`.
  Future<void> _runOp(
    Emitter<BotMaintenanceState> emit,
    MaintenanceOp op,
    Future<void> Function(String botId) action,
  ) async {
    final snapshot = _snapshot();
    if (snapshot == null) return;
    emit(BotMaintenanceBusy(snapshot));
    try {
      await action(_botId);
      emit(BotMaintenanceOpSucceeded(snapshot, op));
      emit(BotMaintenanceLoaded(snapshot));
    } on BotsFailure catch (f) {
      emit(BotMaintenanceOpFailed(snapshot, f));
    }
  }

  /// Snapshot del bot desde un estado estable; null si no hay uno fiable.
  Bot? _snapshot() {
    final s = state;
    if (s is BotMaintenanceLoaded) return s.bot;
    if (s is BotMaintenanceOpFailed) return s.bot;
    if (s is BotMaintenanceOpSucceeded) return s.bot;
    return null;
  }
}

// Events --------------------------------------------------------------------

sealed class BotMaintenanceEvent {
  const BotMaintenanceEvent();
}

class BotMaintenanceLoadRequested extends BotMaintenanceEvent {
  const BotMaintenanceLoadRequested();
  @override
  bool operator ==(Object other) => other is BotMaintenanceLoadRequested;
  @override
  int get hashCode => (BotMaintenanceLoadRequested).hashCode;
}

class BotMaintenancePauseToggled extends BotMaintenanceEvent {
  const BotMaintenancePauseToggled();
  @override
  bool operator ==(Object other) => other is BotMaintenancePauseToggled;
  @override
  int get hashCode => (BotMaintenancePauseToggled).hashCode;
}

class BotMaintenanceClearRequested extends BotMaintenanceEvent {
  const BotMaintenanceClearRequested();
  @override
  bool operator ==(Object other) => other is BotMaintenanceClearRequested;
  @override
  int get hashCode => (BotMaintenanceClearRequested).hashCode;
}

class BotMaintenanceResetRequested extends BotMaintenanceEvent {
  const BotMaintenanceResetRequested();
  @override
  bool operator ==(Object other) => other is BotMaintenanceResetRequested;
  @override
  int get hashCode => (BotMaintenanceResetRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class BotMaintenanceState {
  const BotMaintenanceState();
}

class BotMaintenanceLoading extends BotMaintenanceState {
  const BotMaintenanceLoading();
  @override
  bool operator ==(Object other) => other is BotMaintenanceLoading;
  @override
  int get hashCode => (BotMaintenanceLoading).hashCode;
}

class BotMaintenanceLoaded extends BotMaintenanceState {
  const BotMaintenanceLoaded(this.bot);

  final Bot bot;

  @override
  bool operator ==(Object other) =>
      other is BotMaintenanceLoaded && other.bot == bot;
  @override
  int get hashCode => bot.hashCode;
}

class BotMaintenanceFailed extends BotMaintenanceState {
  const BotMaintenanceFailed(this.failure);

  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotMaintenanceFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

/// Una op (pausa/clear/reset) está en vuelo; el bot sigue visible inhabilitado.
class BotMaintenanceBusy extends BotMaintenanceState {
  const BotMaintenanceBusy(this.bot);

  final Bot bot;

  @override
  bool operator ==(Object other) =>
      other is BotMaintenanceBusy && other.bot == bot;
  @override
  int get hashCode => bot.hashCode;
}

/// Op fallida: conserva el snapshot. `BotsNotPausedFailure` = clear/reset sin
/// pausa (estado stale); otras = red/server/etc.
class BotMaintenanceOpFailed extends BotMaintenanceState {
  const BotMaintenanceOpFailed(this.bot, this.failure);

  final Bot bot;
  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotMaintenanceOpFailed &&
      other.bot == bot &&
      other.failure == failure;
  @override
  int get hashCode => Object.hash(bot, failure);
}

/// Op destructiva exitosa (transitorio): la UI confirma con un snackbar y el
/// bloc vuelve a `Loaded`.
class BotMaintenanceOpSucceeded extends BotMaintenanceState {
  const BotMaintenanceOpSucceeded(this.bot, this.op);

  final Bot bot;
  final MaintenanceOp op;

  @override
  bool operator ==(Object other) =>
      other is BotMaintenanceOpSucceeded && other.bot == bot && other.op == op;
  @override
  int get hashCode => Object.hash(bot, op);
}
