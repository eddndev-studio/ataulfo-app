import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/monitor_activity_datasource.dart';
import '../../data/datasources/monitor_catchup_datasource.dart';
import '../../domain/entities/monitor_event.dart';

/// Estado del monitor en vivo: los eventos de actividad del chat abierto, en
/// orden cronológico de llegada. Es la fundación que consumen la línea de
/// tiempo, la píldora de estado del bot y las tarjetas de alerta.
class MonitorLiveState {
  const MonitorLiveState({
    this.events = const <MonitorEvent>[],
    this.reconnecting = false,
    this.stalled = false,
  });

  final List<MonitorEvent> events;

  /// El SSE se cayó y está reintentando: la actividad en vivo puede ir atrasada.
  final bool reconnecting;

  /// La guarda de turno colgado disparó: tras una corrida activa no llegó más
  /// actividad, así que se la presume terminada (su terminal real no se
  /// persiste). La UI deja de mostrar "Pensando…" SIN inventar un evento en la
  /// línea de tiempo; el siguiente evento real lo limpia.
  final bool stalled;

  @override
  bool operator ==(Object other) =>
      other is MonitorLiveState &&
      listEquals(other.events, events) &&
      other.reconnecting == reconnecting &&
      other.stalled == stalled;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(events), reconnecting, stalled);
}

/// Se suscribe al SSE `ai-activity` del chat abierto y acumula los eventos. NO
/// hace el gate de rol: la pantalla/router lo provee SOLO a ADMIN+ (el endpoint
/// también es ADMIN+, defensa en profundidad). El historial se acota a los más
/// recientes para no crecer sin límite en chats largos.
///
/// Si recibe un [MonitorCatchupDatasource], al abrir un chat HIDRATA el timeline
/// con lo que la corrida en curso ya hizo (reusando el log persistido) en vez de
/// arrancar vacío: descubre el run reciente, y si es fresco trae sus entries y
/// las funde con el stream live (deduplicando el borde por timestamp). Como los
/// eventos terminales (completed/failed) NO se persisten, una guarda marca el
/// estado como "colgado" (flag `stalled`) si tras hidratar no llega más actividad
/// — sin ella una corrida recién terminada se quedaría en "Pensando…" para
/// siempre. El flag NO inventa un evento en la línea de tiempo (que sería falso
/// en un turno solo lento): solo apaga el "Pensando…"; el siguiente evento real
/// lo limpia.
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

  /// Guarda de turno colgado: si tras una corrida activa no llega más actividad,
  /// sintetiza el terminal ausente (los reales no se persisten).
  Timer? _guard;

  /// Empieza a observar el (bot, chat). Re-llamar cambia de chat: cancela la
  /// suscripción previa. El cancel NO se espera (un socket SSE vivo puede colgar
  /// al desmontarse y no debe bloquear el cambio de chat ni el cierre).
  void watch(String botId, String chatLid) {
    unawaited(_sub?.cancel());
    _guard?.cancel();
    _guard = null;
    _hydratedRunId = '';
    _snapshotCutoff = null;
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
      emit(MonitorLiveState(events: state.events, reconnecting: true));
      return;
    }
    // El feed quedó vivo de nuevo: apaga el aviso sin sumar al historial ni
    // tocar `stalled` (es salud del SSE, no del turno). No-op si ya estábamos en
    // vivo, para no re-emitir el mismo estado.
    if (e.kind == MonitorEventKind.connected) {
      if (state.reconnecting) {
        emit(MonitorLiveState(events: state.events, stalled: state.stalled));
      }
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
    emit(
      MonitorLiveState(events: _bounded(<MonitorEvent>[...state.events, e])),
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
      emit(MonitorLiveState(events: _bounded(merged)));
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
      // El turno se presume colgado: marca el estado (la píldora/footer dejan de
      // mostrar "Pensando…") en vez de inventar un aiCompleted, que sería falso
      // si el turno solo iba lento. El próximo evento real limpia el flag.
      final events = state.events;
      if (events.isNotEmpty && _isTerminal(events.last)) return;
      emit(MonitorLiveState(events: events, stalled: true));
    });
  }

  @override
  Future<void> close() {
    _guard?.cancel();
    unawaited(_sub?.cancel());
    return super.close();
  }
}
