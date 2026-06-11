import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/session_status.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bot_session_repository.dart';

/// Bloc del estado VIVO de la sesión de canal para el hub del bot
/// (`GET /bots/:id/session`). Vida atada a la ruta `/bots/:id`: carga al
/// montar y sondea con cadencia relajada mientras el detalle está abierto,
/// así el hero de conexión refleja emparejamientos/caídas sin que el
/// operador entre a la pantalla de conexión (y al volver de ella, el hub
/// se actualiza solo).
///
/// Honestidad del dato: un tick fallido NO degrada un `Loaded` previo — no
/// se falsea una desconexión por un fallo de red transitorio (misma regla
/// que el poll de `BotConnectBloc`). Sólo el load inicial fallido produce
/// `Failed`, y un tick exitoso posterior lo recupera.
class BotSessionStatusBloc
    extends Bloc<BotSessionStatusEvent, BotSessionStatusState> {
  BotSessionStatusBloc({
    required BotSessionRepository repo,
    required String botId,
  }) : _repo = repo,
       _botId = botId,
       super(const BotSessionStatusLoading()) {
    on<BotSessionStatusStarted>(_onStarted);
    on<BotSessionStatusPolled>(_onPolled);
  }

  final BotSessionRepository _repo;
  final String _botId;

  /// Cadencia del poll del hub. Más laxa que los 2s del emparejamiento
  /// activo (`BotConnectBloc`): aquí sólo se observa, no se escanea un QR.
  static const Duration _pollInterval = Duration(seconds: 10);

  Timer? _poll;

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    BotSessionStatusStarted event,
    Emitter<BotSessionStatusState> emit,
  ) async {
    try {
      final status = await _repo.getSessionState(_botId);
      emit(BotSessionStatusLoaded(status));
    } on BotsFailure {
      emit(const BotSessionStatusFailed());
    }
    // El poll arranca pase lo que pase: desde Failed, un tick exitoso
    // recupera el hero sin exigir acción del operador.
    _poll?.cancel();
    _poll = Timer.periodic(
      _pollInterval,
      (_) => add(const BotSessionStatusPolled()),
    );
  }

  Future<void> _onPolled(
    BotSessionStatusPolled event,
    Emitter<BotSessionStatusState> emit,
  ) async {
    try {
      final status = await _repo.getSessionState(_botId);
      emit(BotSessionStatusLoaded(status));
    } on BotsFailure {
      // Tick transitorio fallido: conservar el último estado bueno; el
      // siguiente tick reintenta.
    }
  }
}

// Events ----------------------------------------------------------------------

sealed class BotSessionStatusEvent {
  const BotSessionStatusEvent();
}

/// Carga inicial del estado y arranque del poll. Lo despacha el router al
/// montar la ruta del detalle.
class BotSessionStatusStarted extends BotSessionStatusEvent {
  const BotSessionStatusStarted();
  @override
  bool operator ==(Object other) => other is BotSessionStatusStarted;
  @override
  int get hashCode => (BotSessionStatusStarted).hashCode;
}

/// Tick del poll: refresca el estado real. Lo dispara el Timer interno.
class BotSessionStatusPolled extends BotSessionStatusEvent {
  const BotSessionStatusPolled();
  @override
  bool operator ==(Object other) => other is BotSessionStatusPolled;
  @override
  int get hashCode => (BotSessionStatusPolled).hashCode;
}

// States ----------------------------------------------------------------------

sealed class BotSessionStatusState {
  const BotSessionStatusState();
}

class BotSessionStatusLoading extends BotSessionStatusState {
  const BotSessionStatusLoading();
  @override
  bool operator ==(Object other) => other is BotSessionStatusLoading;
  @override
  int get hashCode => (BotSessionStatusLoading).hashCode;
}

class BotSessionStatusLoaded extends BotSessionStatusState {
  const BotSessionStatusLoaded(this.status);

  final SessionStatus status;

  @override
  bool operator ==(Object other) =>
      other is BotSessionStatusLoaded && other.status == status;
  @override
  int get hashCode => status.hashCode;
}

/// El load inicial falló (p. ej. red caída o rol sin acceso al endpoint).
/// El hero degrada a "estado no disponible" con el CTA intacto; el poll
/// sigue intentando recuperarlo.
class BotSessionStatusFailed extends BotSessionStatusState {
  const BotSessionStatusFailed();
  @override
  bool operator ==(Object other) => other is BotSessionStatusFailed;
  @override
  int get hashCode => (BotSessionStatusFailed).hashCode;
}
