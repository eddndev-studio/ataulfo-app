import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/monitor_activity_datasource.dart';
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
class MonitorLiveCubit extends Cubit<MonitorLiveState> {
  MonitorLiveCubit(this._ds, {int maxEvents = 100})
    : _max = maxEvents,
      super(const MonitorLiveState());

  final MonitorActivityDatasource _ds;
  final int _max;
  StreamSubscription<MonitorEvent>? _sub;

  /// Empieza a observar el (bot, chat). Re-llamar cambia de chat: cancela la
  /// suscripción previa. El cancel NO se espera (un socket SSE vivo puede colgar
  /// al desmontarse y no debe bloquear el cambio de chat ni el cierre).
  void watch(String botId, String chatLid) {
    unawaited(_sub?.cancel());
    _sub = _ds.activity(botId, chatLid).listen(
      (e) {
        if (isClosed) return;
        // El sentinel de reconexión no es actividad del bot: marca el estado de
        // salud del SSE, sin sumar al historial.
        if (e.kind == MonitorEventKind.reconnect) {
          emit(MonitorLiveState(events: state.events, reconnecting: true));
          return;
        }
        final next = <MonitorEvent>[...state.events, e];
        final bounded = next.length > _max
            ? next.sublist(next.length - _max)
            : next;
        // Un evento real ⇒ el stream está vivo otra vez.
        emit(MonitorLiveState(events: bounded));
      },
      onError: (Object _) {},
    );
  }

  @override
  Future<void> close() {
    unawaited(_sub?.cancel());
    return super.close();
  }
}
