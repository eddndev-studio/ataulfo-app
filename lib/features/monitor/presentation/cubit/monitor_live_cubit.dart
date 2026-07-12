import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/monitor_activity_datasource.dart';
import '../../data/datasources/monitor_catchup_datasource.dart';
import '../../domain/entities/monitor_event.dart';

/// El último fallo del monitor, RETENIDO tras cerrar la corrida: una corrida
/// de IA (con runId ⇒ el tap de la pill abre su traza) o un flujo (sin runId ⇒
/// el tap abre Ejecuciones). `error` es el CRUDO del wire: solo alimenta el
/// copy es-MX / el detalle técnico secundario — jamás se pinta tal cual.
class MonitorFailure {
  const MonitorFailure({
    required this.isFlow,
    required this.runId,
    required this.error,
  });

  final bool isFlow;
  final String runId;
  final String error;

  @override
  bool operator ==(Object other) =>
      other is MonitorFailure &&
      other.isFlow == isFlow &&
      other.runId == runId &&
      other.error == error;

  @override
  int get hashCode => Object.hash(isFlow, runId, error);
}

/// Estado del monitor en vivo: los eventos de la actividad VIGENTE del chat
/// abierto (la corrida de IA en curso o el carril solo-flujo), en orden de
/// llegada. Es la fundación que consumen la mini-traza del footer, la píldora
/// de estado del bot y las tarjetas de alerta.
class MonitorLiveState {
  const MonitorLiveState({
    this.events = const <MonitorEvent>[],
    this.runId = '',
    this.failure,
    this.alert,
    this.reconnecting = false,
    this.stalled = false,
    this.truncated = false,
  });

  /// Eventos de la actividad vigente. Un terminal de corrida la VACÍA (la
  /// traza viva es del turno en vuelo; el desenlace vive en la pill/failure).
  final List<MonitorEvent> events;

  /// Corrida vigente ('' = carril solo-flujo o reposo). Un frame ai.* con otro
  /// runId arranca lista fresca; el rezagado de una corrida cerrada se descarta.
  final String runId;

  /// Último fallo retenido (corrida o flujo) para la pill clicable. Lo limpia
  /// cualquier actividad posterior (el bot volvió a trabajar) o un completed.
  final MonitorFailure? failure;

  /// Última alerta del agente (agent.alert), RETENIDA para el banner: una
  /// señal crítica no es un paso de la traza y no la barre el cierre de la
  /// corrida — la descarta el operador (X del banner) o la pisa otra alerta.
  final MonitorEvent? alert;

  /// El SSE se cayó y está reintentando: la actividad en vivo puede ir atrasada.
  final bool reconnecting;

  /// La guarda de turno colgado disparó: tras una corrida activa no llegó más
  /// actividad, así que se la presume terminada (su terminal real no se
  /// persiste). La UI deja de mostrar "Pensando…" SIN inventar un evento en la
  /// línea de tiempo; el siguiente evento real lo limpia.
  final bool stalled;

  /// El tope de eventos descartó la cabeza de la lista: la entrada ya no es
  /// el arranque real y la traza queda PARCIAL de forma pegajosa — si
  /// `parcial` se re-derivara de la nueva cabeza, el resumen inventaría un N
  /// definitivo con solo los eventos visibles. Espejo del parcial sticky del
  /// reductor web.
  final bool truncated;

  @override
  bool operator ==(Object other) =>
      other is MonitorLiveState &&
      listEquals(other.events, events) &&
      other.runId == runId &&
      other.failure == failure &&
      other.alert == alert &&
      other.reconnecting == reconnecting &&
      other.stalled == stalled &&
      other.truncated == truncated;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(events),
    runId,
    failure,
    alert,
    reconnecting,
    stalled,
    truncated,
  );
}

/// Se suscribe al SSE `ai-activity` del chat abierto y acumula los eventos de
/// la actividad VIGENTE (espejo del reductor del panel web). NO hace el gate
/// de rol: la pantalla/router lo provee SOLO a ADMIN+ (el endpoint también es
/// ADMIN+, defensa en profundidad).
///
/// Reglas del run vigente:
///  - `ai.completed`/`ai.failed` cierran la corrida ⇒ lista vacía (el fallo lo
///    retiene `failure`, no la timeline).
///  - `flow.completed`/`flow.failed` solo cierran la actividad SOLO-FLUJO
///    (runId ''): dentro de una corrida IA el flujo es un paso más de ella.
///  - Un frame ai.* con OTRO runId es una corrida nueva ⇒ lista fresca; el
///    frame rezagado de una corrida YA cerrada NO se anexa.
///  - `agent.alert` y topics desconocidos dejan la actividad intacta.
///  - Cambio de chat (re-watch) resetea el estado.
///
/// Si recibe un [MonitorCatchupDatasource], al abrir un chat HIDRATA el
/// timeline con lo que la corrida en curso ya hizo (reusando el log
/// persistido); la guarda de 90s marca `stalled` si tras hidratar no llega más
/// actividad (los terminales no se persisten).
class MonitorLiveCubit extends Cubit<MonitorLiveState> {
  MonitorLiveCubit(
    this._ds, {
    int maxEvents = 100,
    MonitorCatchupDatasource? catchup,
    Duration freshness = const Duration(minutes: 5),
    Duration stuckTurnTimeout = const Duration(seconds: 90),
  }) : _max = maxEvents,
       _catchup = catchup,
       _freshness = freshness,
       _stuckTimeout = stuckTurnTimeout,
       super(const MonitorLiveState());

  final MonitorActivityDatasource _ds;
  final int _max;
  final MonitorCatchupDatasource? _catchup;
  final Duration _freshness;
  final Duration _stuckTimeout;

  StreamSubscription<MonitorEvent>? _sub;

  /// Corrida hidratada y su corte: los eventos live del MISMO run con `at` <=
  /// corte son duplicados del snapshot y se descartan.
  String _hydratedRunId = '';
  DateTime? _snapshotCutoff;

  /// Última corrida CERRADA en vivo: su frame rezagado no se anexa y la
  /// hidratación no la resucita (el snapshot no trae el terminal).
  String _closedRunId = '';

  /// Guarda de turno colgado: si tras una corrida activa no llega más
  /// actividad, apaga el "Pensando…" (los terminales reales no se persisten).
  Timer? _guard;

  /// Empieza a observar el (bot, chat). Re-llamar cambia de chat: cancela la
  /// suscripción previa y RESETEA el estado (la actividad del chat anterior no
  /// debe pintarse sobre el nuevo). El cancel NO se espera (un socket SSE vivo
  /// puede colgar al desmontarse y no debe bloquear el cambio de chat).
  void watch(String botId, String chatLid) {
    unawaited(_sub?.cancel());
    _guard?.cancel();
    _guard = null;
    _hydratedRunId = '';
    _snapshotCutoff = null;
    _closedRunId = '';
    // Reset del chat anterior. Guardado: el PRIMER emit de un Cubit pasa
    // aunque el estado sea igual, y re-emitir el inicial ensucia blocTest.
    if (state != const MonitorLiveState()) emit(const MonitorLiveState());
    _sub = _ds
        .activity(botId, chatLid)
        .listen(_onEvent, onError: (Object _) {});
    if (_catchup != null) unawaited(_hydrate(botId, chatLid));
  }

  void _onEvent(MonitorEvent e) {
    if (isClosed) return;
    // El sentinel de reconexión no es actividad del bot: marca el estado de
    // salud del SSE, sin sumar al historial.
    if (e.kind == MonitorEventKind.reconnect) {
      emit(_copyWith(reconnecting: true));
      return;
    }
    // El feed quedó vivo de nuevo: apaga el aviso sin sumar al historial ni
    // tocar `stalled` (es salud del SSE, no del turno). No-op si ya estábamos
    // en vivo, para no re-emitir el mismo estado.
    if (e.kind == MonitorEventKind.connected) {
      if (state.reconnecting) emit(_copyWith(reconnecting: false));
      return;
    }
    if (_catchup != null) {
      final cutoff = _snapshotCutoff;
      // Duplicado del snapshot: el mismo run, dentro de la ventana ya hidratada.
      if (cutoff != null &&
          e.runId == _hydratedRunId &&
          !e.at.isAfter(cutoff)) {
        return;
      }
      _rearmGuard(e);
    }
    _applyActivity(e);
  }

  /// Terminal de OTRA corrida (jitter del bus): no puede apagar la vigente ni
  /// anunciar su fallo como si fuera de ella. Solo compara con ambos runId en
  /// mano — un terminal degradado sin runId sigue cerrando la vigente.
  bool _foreignTerminal(MonitorEvent e) =>
      _isTerminal(e) &&
      e.runId.isNotEmpty &&
      state.runId.isNotEmpty &&
      e.runId != state.runId;

  /// Reduce un evento real sobre la actividad vigente (ver doc de la clase).
  void _applyActivity(MonitorEvent e) {
    if (_foreignTerminal(e)) return;
    switch (e.kind) {
      case MonitorEventKind.aiCompleted:
        _closedRunId = e.runId;
        emit(MonitorLiveState(alert: state.alert));
      case MonitorEventKind.aiFailed:
        _closedRunId = e.runId;
        emit(
          MonitorLiveState(
            failure: MonitorFailure(
              isFlow: false,
              runId: e.runId,
              error: e.error,
            ),
            alert: state.alert,
          ),
        );
      case MonitorEventKind.flowCompleted:
        // Solo cierra el carril solo-flujo; dentro de una corrida es un paso.
        if (state.runId.isEmpty) {
          emit(MonitorLiveState(alert: state.alert));
        }
      case MonitorEventKind.flowFailed:
        if (state.runId.isEmpty) {
          emit(
            MonitorLiveState(
              failure: MonitorFailure(isFlow: true, runId: '', error: e.error),
              alert: state.alert,
            ),
          );
        } else {
          // El flujo falló como paso de la corrida: la corrida sigue; retener
          // el fallo de flujo pisaría el desenlace real (ai.completed/failed).
        }
      case MonitorEventKind.aiTurn:
      case MonitorEventKind.aiTool:
        // El frame rezagado de una corrida YA cerrada no se anexa.
        if (e.runId.isNotEmpty && e.runId == _closedRunId) return;
        if (e.runId != state.runId) {
          // Corrida nueva: lista fresca; la actividad nueva limpia el fallo.
          emit(
            MonitorLiveState(
              events: <MonitorEvent>[e],
              runId: e.runId,
              alert: state.alert,
            ),
          );
        } else {
          emit(_appended(e));
        }
      case MonitorEventKind.flowStarted:
      case MonitorEventKind.flowStep:
        emit(_appended(e));
      case MonitorEventKind.alert:
        // No es un paso de la traza viva: se retiene aparte para el banner.
        emit(
          MonitorLiveState(
            events: state.events,
            runId: state.runId,
            failure: state.failure,
            alert: e,
            stalled: state.stalled,
          ),
        );
      case MonitorEventKind.unknown:
      case MonitorEventKind.reconnect:
      case MonitorEventKind.connected:
        // Topics futuros no son pasos de la traza viva: la dejan intacta;
        // solo apagan el aviso de salud (el frame llegó = feed vivo).
        if (state.reconnecting) emit(_copyWith(reconnecting: false));
    }
  }

  /// Copia del estado tocando SOLO la salud del SSE (conserva actividad,
  /// fallo y alerta).
  MonitorLiveState _copyWith({required bool reconnecting}) => MonitorLiveState(
    events: state.events,
    runId: state.runId,
    failure: state.failure,
    alert: state.alert,
    reconnecting: reconnecting,
    stalled: state.stalled,
    truncated: state.truncated,
  );

  /// Anexa un evento a la actividad vigente aplicando el tope: si el tope
  /// descartó la cabeza, `truncated` queda pegajoso (la traza es parcial de
  /// ahí en adelante — el resumen no puede inventar N con la lista recortada).
  MonitorLiveState _appended(MonitorEvent e) {
    final full = <MonitorEvent>[...state.events, e];
    final bounded = _bounded(full);
    return MonitorLiveState(
      events: bounded,
      runId: state.runId,
      alert: state.alert,
      truncated: state.truncated || bounded.length < full.length,
    );
  }

  Future<void> _hydrate(String botId, String chatLid) async {
    final catchup = _catchup;
    if (catchup == null) return;
    try {
      final run = await catchup.activeRun(botId, chatLid);
      if (run == null || isClosed) return;
      // Gate de frescura: solo una corrida reciente vale hidratar; una vieja
      // pintaría un "Pensando…" espurio al abrir un chat inactivo.
      if (DateTime.now().toUtc().difference(run.at) > _freshness) return;
      final snapshot = await catchup.catchup(botId, chatLid, run.runId);
      if (isClosed) return;
      // El terminal llegó en vivo DURANTE la hidratación: la corrida ya cerró
      // y el snapshot (sin terminal) no debe resucitar su "Pensando…".
      if (run.runId == _closedRunId) return;
      // Una corrida NUEVA arrancó en vivo durante el fetch: el snapshot viejo
      // no puede pisarle el runId ni fundir sus frames con los de ella.
      if (state.runId.isNotEmpty && state.runId != run.runId) return;
      final cutoff = snapshot.isEmpty
          ? run.at
          : snapshot.map((e) => e.at).reduce((a, b) => a.isAfter(b) ? a : b);
      _hydratedRunId = run.runId;
      _snapshotCutoff = cutoff;
      // Funde el snapshot con lo que ya llegó live (subscribe-first): conserva
      // los live posteriores al corte y ordena por `at`.
      final keptLive = state.events
          .where((e) => e.at.isAfter(cutoff))
          .toList(growable: true);
      final merged = <MonitorEvent>[...snapshot, ...keptLive]
        ..sort((a, b) => a.at.compareTo(b.at));
      final bounded = _bounded(merged);
      emit(
        MonitorLiveState(
          events: bounded,
          runId: run.runId,
          failure: state.failure,
          alert: state.alert,
          reconnecting: state.reconnecting,
          truncated: state.truncated || bounded.length < merged.length,
        ),
      );
      // Solo armar si el turno sigue abierto: si un terminal real ya llegó live
      // durante la hidratación, no hay nada que vigilar (evita marcar colgado un
      // run ya cerrado).
      if (merged.isNotEmpty && !_isTerminal(merged.last)) _armGuard(run.runId);
    } on Object {
      // Hidratar es best-effort: cualquier fallo deja el monitor como hoy
      // (arranca vacío y se llena con lo live).
    }
  }

  List<MonitorEvent> _bounded(List<MonitorEvent> events) =>
      events.length > _max ? events.sublist(events.length - _max) : events;

  static bool _isTerminal(MonitorEvent e) =>
      e.kind == MonitorEventKind.aiCompleted ||
      e.kind == MonitorEventKind.aiFailed;

  /// Re-arma la guarda en cada actividad: un evento terminal real la cancela
  /// (no hay turno colgado); uno no-terminal reinicia la cuenta.
  void _rearmGuard(MonitorEvent e) {
    if (_isTerminal(e)) {
      // Un terminal ajeno (jitter) tampoco cancela la vigilancia del run
      // vigente: su corrida sigue viva y colgable.
      if (_foreignTerminal(e)) return;
      _guard?.cancel();
      _guard = null;
      return;
    }
    if (e.runId.isNotEmpty) _armGuard(e.runId);
  }

  void _armGuard(String runId) {
    _guard?.cancel();
    _guard = Timer(_stuckTimeout, () {
      _guard = null;
      if (isClosed) return;
      // El turno se presume colgado: marca el estado (la píldora/footer dejan
      // de mostrar "Pensando…") en vez de inventar un terminal, que sería
      // falso si el turno solo iba lento. El próximo evento real limpia el
      // flag (los estados que emite _applyActivity nacen con stalled=false).
      emit(
        MonitorLiveState(
          events: state.events,
          runId: state.runId,
          failure: state.failure,
          alert: state.alert,
          reconnecting: state.reconnecting,
          stalled: true,
        ),
      );
    });
  }

  @override
  Future<void> close() {
    _guard?.cancel();
    unawaited(_sub?.cancel());
    return super.close();
  }
}
