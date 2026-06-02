import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/connect_link.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bot_session_repository.dart';

/// Fase del emparejamiento dentro del estado Ready: el enlace ya existe y se
/// puede compartir; arrancar la sesión es una acción aparte y tardía.
enum PairingPhase { idle, starting, active, failed }

/// Bloc del flujo "compartir enlace de conexión" (S04). Vida atada a la ruta
/// `/bots/:id/connect`.
///
/// Diseño de dos tiempos, dictado por el ciclo de vida real del QR: el código
/// de whatsmeow vive ~2 min (al expirar, la sesión cae a DISCONNECTED y NO se
/// reintenta), pero el ConnectToken dura 15 min y el enlace lo abre un tercero
/// más tarde. Por eso:
///  - [BotConnectStarted] SOLO emite el enlace (mint): se puede compartir ya,
///    con holgura de TTL.
///  - [BotConnectPairingRequested] arranca la sesión, idealmente justo cuando
///    el tercero está por escanear, para que el QR esté vivo en ese momento.
/// Arrancar al emitir cerraría la ventana del QR antes de que abran el enlace.
class BotConnectBloc extends Bloc<BotConnectEvent, BotConnectState> {
  BotConnectBloc({required BotSessionRepository repo, required String botId})
    : _repo = repo,
      _botId = botId,
      super(const BotConnectLoading()) {
    on<BotConnectStarted>(_onStarted);
    on<BotConnectPairingRequested>(_onPairingRequested);
    on<BotConnectStopRequested>(_onStopRequested);
  }

  final BotSessionRepository _repo;
  final String _botId;

  Future<void> _onStarted(
    BotConnectStarted event,
    Emitter<BotConnectState> emit,
  ) async {
    // Sólo re-emitimos Loading en un retry (desde Failed); el primer load ya
    // está en Loading. Mismo patrón que BotDetailBloc.
    if (state is! BotConnectLoading) {
      emit(const BotConnectLoading());
    }
    try {
      final link = await _repo.issueConnectLink(_botId);
      emit(BotConnectReady(link));
    } on BotsFailure catch (f) {
      emit(BotConnectFailed(f));
    }
  }

  Future<void> _onPairingRequested(
    BotConnectPairingRequested event,
    Emitter<BotConnectState> emit,
  ) async {
    final current = state;
    if (current is! BotConnectReady) {
      return; // sin enlace todavía no hay nada que emparejar
    }
    emit(BotConnectReady(current.link, phase: PairingPhase.starting));
    try {
      await _repo.startSession(_botId);
      emit(BotConnectReady(current.link, phase: PairingPhase.active));
    } on BotsFailure {
      emit(BotConnectReady(current.link, phase: PairingPhase.failed));
    }
  }

  Future<void> _onStopRequested(
    BotConnectStopRequested event,
    Emitter<BotConnectState> emit,
  ) async {
    final current = state;
    if (current is! BotConnectReady) {
      return; // sin enlace todavía no hay sesión que detener
    }
    // `DELETE /bots/:id/session` es idempotente (204 aun si no corría). Desde
    // la perspectiva del operador el emparejamiento queda cancelado pase lo
    // que pase, así que volvemos a `idle` (re-ofrecer Iniciar) incluso si la
    // llamada falla. La máquina de estados real (poll + estado del backend)
    // aterriza después; aquí el botón es un disparo simple.
    try {
      await _repo.stopSession(_botId);
    } on BotsFailure {
      // Idempotente: tratar el fallo como ya-detenido.
    }
    emit(BotConnectReady(current.link));
  }
}

// Events --------------------------------------------------------------------

sealed class BotConnectEvent {
  const BotConnectEvent();
}

/// Abre el flujo: emite el enlace de conexión (mint). No arranca la sesión.
class BotConnectStarted extends BotConnectEvent {
  const BotConnectStarted();
  @override
  bool operator ==(Object other) => other is BotConnectStarted;
  @override
  int get hashCode => (BotConnectStarted).hashCode;
}

/// Arranca la sesión del bot (→ PAIRING): el QR queda vivo ~2 min. Se dispara
/// cuando el tercero está por escanear.
class BotConnectPairingRequested extends BotConnectEvent {
  const BotConnectPairingRequested();
  @override
  bool operator ==(Object other) => other is BotConnectPairingRequested;
  @override
  int get hashCode => (BotConnectPairingRequested).hashCode;
}

/// Detiene la sesión / cancela el emparejamiento (`DELETE /bots/:id/session`,
/// idempotente). Vuelve la fase a `idle` para re-ofrecer Iniciar.
class BotConnectStopRequested extends BotConnectEvent {
  const BotConnectStopRequested();
  @override
  bool operator ==(Object other) => other is BotConnectStopRequested;
  @override
  int get hashCode => (BotConnectStopRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class BotConnectState {
  const BotConnectState();
}

class BotConnectLoading extends BotConnectState {
  const BotConnectLoading();
  @override
  bool operator ==(Object other) => other is BotConnectLoading;
  @override
  int get hashCode => (BotConnectLoading).hashCode;
}

/// El enlace está listo para compartir. [phase] refleja el estado de la
/// sesión que el operador arranca aparte.
class BotConnectReady extends BotConnectState {
  const BotConnectReady(this.link, {this.phase = PairingPhase.idle});

  final ConnectLink link;
  final PairingPhase phase;

  @override
  bool operator ==(Object other) =>
      other is BotConnectReady && other.link == link && other.phase == phase;
  @override
  int get hashCode => Object.hash(link, phase);
}

/// La emisión del enlace falló (no hay enlace). El retry re-emite el enlace.
class BotConnectFailed extends BotConnectState {
  const BotConnectFailed(this.failure);

  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotConnectFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
