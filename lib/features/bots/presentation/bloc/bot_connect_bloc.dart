import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/connect_link.dart';
import '../../domain/entities/session_status.dart';
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
    on<BotConnectWipeRequested>(_onWipeRequested);
    on<BotConnectStatusPolled>(_onStatusPolled);
    on<BotConnectPairCodeRequested>(_onPairCodeRequested);
  }

  final BotSessionRepository _repo;
  final String _botId;

  /// Cadencia del poll del estado de sesión mientras el QR está vivo.
  static const Duration _pollInterval = Duration(seconds: 2);

  /// Timer del poll, activo sólo mientras la sesión está transitoria
  /// (PAIRING/CONNECTING/RECONNECTING). Cancelado al alcanzar un estado
  /// terminal, al detener/borrar, y en `close`.
  Timer? _poll;

  /// Generación del poll: la bumpean start/stop. Un `_onStatusPolled` en vuelo
  /// captura la generación al entrar; si cambió tras el `await` (un stop/wipe o
  /// un nuevo arranque ocurrió mientras la red respondía), descarta su
  /// resultado en vez de pisar el estado (evita falsos qrExpired / QR zombi).
  int _pollGen = 0;

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
    _pollGen++;
  }

  void _startPolling() {
    _poll?.cancel();
    _pollGen++;
    _poll = Timer.periodic(
      _pollInterval,
      (_) => add(const BotConnectStatusPolled()),
    );
  }

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
      // La sesión entra en PAIRING: empezamos a sondear el estado real para
      // traer el QR y detectar conexión / expiración.
      _startPolling();
    } on BotsFailure {
      emit(BotConnectReady(current.link, phase: PairingPhase.failed));
    }
  }

  Future<void> _onStatusPolled(
    BotConnectStatusPolled event,
    Emitter<BotConnectState> emit,
  ) async {
    final current = state;
    if (current is! BotConnectReady) {
      _stopPolling();
      return;
    }
    final gen = _pollGen;
    try {
      final status = await _repo.getSessionState(_botId);
      // Si un stop/wipe o un nuevo arranque ocurrió mientras la red respondía,
      // este resultado quedó obsoleto: descartarlo en vez de pisar el estado
      // (evita un falso qrExpired tras cancelar, o resucitar un QR zombi).
      if (gen != _pollGen) return;
      // Otros handlers interleavan con este await (p. ej. el 200 de
      // pair-phone pintando el código): el snapshot de la entrada quedó
      // viejo — releer y acarrear SIEMPRE desde el estado fresco, o este
      // emit pisaría el código recién pintado y dejaría pairRequesting
      // clavado en true (spinner eterno + pedidas bloqueadas).
      final latest = state;
      if (latest is! BotConnectReady) return;
      // El QR de whatsmeow vive ~2 min: si veníamos en PAIRING y el backend
      // reporta DISCONNECTED, el código expiró (no es un fallo).
      final wasPairing = latest.status?.state == SessionState.pairing;
      final qrExpired = wasPairing && status.state == SessionState.disconnected;
      // PAIRING/CONNECTING/RECONNECTING son transitorios que justifican seguir
      // sondeando; en cualquier otro estado (CONNECTED/DISCONNECTED) paramos.
      final keepPolling =
          status.state == SessionState.pairing ||
          status.state == SessionState.connecting ||
          status.state == SessionState.reconnecting;
      if (!keepPolling) _stopPolling();
      emit(
        BotConnectReady(
          latest.link,
          phase: latest.phase,
          status: status,
          qrExpired: qrExpired,
          // El código tecleable comparte la ventana del QR: la expiración
          // mata a ambos. Mientras la sesión siga transitoria se preservan.
          pairCode: qrExpired ? null : latest.pairCode,
          pairRequesting: latest.pairRequesting,
          pairFailure: qrExpired ? null : latest.pairFailure,
        ),
      );
    } on BotsFailure {
      // Poll transitorio fallido: el siguiente tick reintenta. No degradamos
      // el estado visible (no falseamos una desconexión por un fallo de red).
    }
  }

  Future<void> _onPairCodeRequested(
    BotConnectPairCodeRequested event,
    Emitter<BotConnectState> emit,
  ) async {
    final current = state;
    // Precondición dura del backend: el código sólo existe con la sesión en
    // PAIRING (el mismo branch que muestra el QR); fuera de ahí contestaría
    // 409. Una pedida en vuelo gatea la re-entrada (el loading del botón
    // bloquea el doble-tap, este guard cubre el resto de los caminos).
    if (current is! BotConnectReady) return;
    if (current.status?.state != SessionState.pairing) return;
    if (current.pairRequesting) return;
    // Cada pedida invalida la anterior en whatsmeow: el código viejo se
    // limpia ANTES del POST para no mostrar uno ya muerto mientras llega el
    // nuevo.
    emit(
      BotConnectReady(
        current.link,
        phase: current.phase,
        status: current.status,
        qrExpired: current.qrExpired,
        pairRequesting: true,
      ),
    );
    final gen = _pollGen;
    try {
      final code = await _repo.pairPhone(_botId, event.phone);
      // Un stop/wipe o un nuevo arranque en vuelo dejó obsoleto el resultado:
      // descartarlo en vez de resucitar un código muerto.
      if (gen != _pollGen) return;
      final latest = state;
      if (latest is! BotConnectReady) return;
      if (latest.status?.state != SessionState.pairing) {
        // La sesión salió de PAIRING mientras la red respondía (p. ej. ya
        // están vinculando por el QR): pintar el código sería mostrar uno
        // muerto. Sólo se apaga el spinner.
        emit(
          BotConnectReady(
            latest.link,
            phase: latest.phase,
            status: latest.status,
            qrExpired: latest.qrExpired,
          ),
        );
        return;
      }
      emit(
        BotConnectReady(
          latest.link,
          phase: latest.phase,
          status: latest.status,
          qrExpired: latest.qrExpired,
          pairCode: code,
        ),
      );
    } on BotsFailure catch (f) {
      if (gen != _pollGen) return;
      final latest = state;
      if (latest is! BotConnectReady) return;
      if (latest.status?.state != SessionState.pairing) {
        // La sección pair-phone ya no está visible: escribir el fallo dejaría
        // un error fantasma listo para reaparecer si la sesión rebota a
        // PAIRING. Solo se apaga el spinner (espejo del camino de éxito).
        emit(
          BotConnectReady(
            latest.link,
            phase: latest.phase,
            status: latest.status,
            qrExpired: latest.qrExpired,
          ),
        );
        return;
      }
      // Fallo local a la sección de pair-phone: el QR sigue vivo, así que no
      // se degrada a una fase failed global.
      emit(
        BotConnectReady(
          latest.link,
          phase: latest.phase,
          status: latest.status,
          qrExpired: latest.qrExpired,
          pairFailure: f,
        ),
      );
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
    _stopPolling();
    try {
      await _repo.stopSession(_botId);
    } on BotsFailure {
      // Idempotente: tratar el fallo como ya-detenido.
    }
    emit(BotConnectReady(current.link));
  }

  Future<void> _onWipeRequested(
    BotConnectWipeRequested event,
    Emitter<BotConnectState> emit,
  ) async {
    final current = state;
    if (current is! BotConnectReady) {
      return;
    }
    // `wipe-credentials` destruye el pareado: el bot re-parea desde cero. Es
    // idempotente (204), así que volvemos a `idle` (re-ofrecer Iniciar) pase lo
    // que pase. NO gateado por `paused` — es Tier B.
    _stopPolling();
    try {
      await _repo.wipeCredentials(_botId);
    } on BotsFailure {
      // Idempotente: tratar el fallo como ya-borrado.
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

/// Borra las credenciales del dispositivo (`wipe-credentials`, idempotente). El
/// bot re-parea desde cero. NO gateado por `paused` (Tier B).
class BotConnectWipeRequested extends BotConnectEvent {
  const BotConnectWipeRequested();
  @override
  bool operator ==(Object other) => other is BotConnectWipeRequested;
  @override
  int get hashCode => (BotConnectWipeRequested).hashCode;
}

/// Tick del poll: consulta `GET /bots/:id/session` y actualiza el estado real.
/// Lo dispara el Timer interno mientras la sesión está PAIRING/CONNECTING.
class BotConnectStatusPolled extends BotConnectEvent {
  const BotConnectStatusPolled();
  @override
  bool operator ==(Object other) => other is BotConnectStatusPolled;
  @override
  int get hashCode => (BotConnectStatusPolled).hashCode;
}

/// Pide el código de vinculación por teléfono (`pair-phone`), la vía alterna
/// al QR. [phone] llega YA saneado y validado por la UI (dígitos pelados en
/// formato internacional). Sólo procede con la sesión en PAIRING.
class BotConnectPairCodeRequested extends BotConnectEvent {
  const BotConnectPairCodeRequested(this.phone);

  final String phone;

  @override
  bool operator ==(Object other) =>
      other is BotConnectPairCodeRequested && other.phone == phone;
  @override
  int get hashCode => Object.hash(BotConnectPairCodeRequested, phone);
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

/// El enlace está listo para compartir. [phase] refleja la acción optimista que
/// el operador arranca aparte; [status] es el estado REAL de la sesión que el
/// poll trae del backend (null hasta el primer poll). El QR escaneable
/// (`status.qrCode`) sólo viene en `SessionState.pairing`. [qrExpired] marca la
/// transición PAIRING→DISCONNECTED (el código de ~2 min caducó).
///
/// [pairCode] es el código de vinculación por teléfono (YA formateado
/// `XXXX-XXXX`; se pinta tal cual), la vía alterna al QR con su misma ventana
/// de vida; [pairRequesting] marca la pedida en vuelo y [pairFailure] su
/// fallo, local a esa sección (el QR sigue vivo).
class BotConnectReady extends BotConnectState {
  const BotConnectReady(
    this.link, {
    this.phase = PairingPhase.idle,
    this.status,
    this.qrExpired = false,
    this.pairCode,
    this.pairRequesting = false,
    this.pairFailure,
  });

  final ConnectLink link;
  final PairingPhase phase;
  final SessionStatus? status;
  final bool qrExpired;
  final String? pairCode;
  final bool pairRequesting;
  final BotsFailure? pairFailure;

  @override
  bool operator ==(Object other) =>
      other is BotConnectReady &&
      other.link == link &&
      other.phase == phase &&
      other.status == status &&
      other.qrExpired == qrExpired &&
      other.pairCode == pairCode &&
      other.pairRequesting == pairRequesting &&
      other.pairFailure == pairFailure;
  @override
  int get hashCode => Object.hash(
    link,
    phase,
    status,
    qrExpired,
    pairCode,
    pairRequesting,
    pairFailure,
  );
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
