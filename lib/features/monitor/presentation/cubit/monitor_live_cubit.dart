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
  });

  final List<MonitorEvent> events;

  /// El SSE se cayó y está reintentando: la actividad en vivo puede ir atrasada.
  final bool reconnecting;

  @override
  bool operator ==(Object other) =>
      other is MonitorLiveState &&
      listEquals(other.events, events) &&
      other.reconnecting == reconnecting;

  @override
  int get hashCode => Object.hash(Object.hashAll(events), reconnecting);
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
/// eventos terminales (completed/failed) NO se persisten, una guarda de turno
/// colgado sintetiza el cierre si tras hidratar no llega más actividad — sin ella
/// una corrida recién terminada se quedaría en "Pensando…" para siempre.
class MonitorLiveCubit extends Cubit<MonitorLiveState> {
  MonitorLiveCubit(
    this._ds, {
    int maxEvents = 100,
    MonitorCatchupDatasource? catchup,
    Duration freshness = const Duration(minutes: 5),
    Duration stuckTurnTimeout = const Duration(seconds: 40),
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
    _sub = _ds.activity(botId, chatLid).listen(_onEvent, onError: (Object _) {});
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
    emit(MonitorLiveState(events: _bounded(<MonitorEvent>[...state.events, e])));
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
      _armGuard(run.runId);
    } on Object {
      // Hidratar es best-effort: cualquier fallo deja el monitor como hoy
      // (arranca vacío y se llena con lo live).
    }
  }

  List<MonitorEvent> _bounded(List<MonitorEvent> events) =>
      events.length > _max ? events.sublist(events.length - _max) : events;

  /// Re-arma la guarda en cada actividad: un evento terminal real la cancela
  /// (no hay turno colgado); uno no-terminal reinicia la cuenta.
  void _rearmGuard(MonitorEvent e) {
    if (e.kind == MonitorEventKind.aiCompleted ||
        e.kind == MonitorEventKind.aiFailed) {
      _guard?.cancel();
      _guard = null;
      return;
    }
    if (e.runId.isNotEmpty) _armGuard(e.runId);
  }

  void _armGuard(String runId) {
    _guard?.cancel();
    _guard = Timer(_stuckTimeout, () {
      if (isClosed) return;
      // Sintetiza el cierre ausente: el footer/píldora derivan "activo" del
      // último evento, así que un aiCompleted al final apaga el "Pensando…".
      emit(
        MonitorLiveState(
          events: _bounded(<MonitorEvent>[
            ...state.events,
            MonitorEvent(
              kind: MonitorEventKind.aiCompleted,
              topic: 'ai.completed',
              at: DateTime.now().toUtc(),
              runId: runId,
            ),
          ]),
        ),
      );
      _guard = null;
    });
  }

  @override
  Future<void> close() {
    _guard?.cancel();
    unawaited(_sub?.cancel());
    return super.close();
  }
}
