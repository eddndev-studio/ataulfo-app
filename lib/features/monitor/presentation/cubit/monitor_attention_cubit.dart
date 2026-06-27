import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/monitor_activity_datasource.dart';
import '../../domain/entities/monitor_event.dart';

/// Chats del bot que necesitan atención del operador (el bot falló o levantó una
/// alerta en ellos). Derivado del feed bot-scoped en vivo.
class MonitorAttentionState {
  const MonitorAttentionState({this.needsAttention = const <String>{}});

  final Set<String> needsAttention;

  @override
  bool operator ==(Object other) =>
      other is MonitorAttentionState &&
      setEquals(other.needsAttention, needsAttention);

  @override
  int get hashCode => Object.hashAll(needsAttention);
}

/// Observa la actividad de TODOS los chats de un bot (tier operador, WORKER+) y
/// mantiene el conjunto de chats con una señal de atención reciente: el bot
/// falló (aiFailed/flowFailed) o levantó una alerta. La bandeja lo usa para
/// destacar esas filas. `clear` retira un chat cuando el operador lo abre.
class MonitorAttentionCubit extends Cubit<MonitorAttentionState> {
  MonitorAttentionCubit(this._ds) : super(const MonitorAttentionState());

  final MonitorBotActivityDatasource _ds;
  StreamSubscription<MonitorEvent>? _sub;

  /// Empieza a observar el bot. El cancel NO se espera (un socket SSE vivo puede
  /// colgar al desmontarse y no debe bloquear).
  void watch(String botId) {
    unawaited(_sub?.cancel());
    _sub = _ds.botActivity(botId).listen((e) {
      if (isClosed || !_needsAttention(e.kind) || e.chatLid.isEmpty) return;
      if (state.needsAttention.contains(e.chatLid)) return;
      emit(
        MonitorAttentionState(
          needsAttention: <String>{...state.needsAttention, e.chatLid},
        ),
      );
    }, onError: (Object _) {});
  }

  /// Retira un chat del conjunto (el operador lo abrió / lo atendió).
  void clear(String chatLid) {
    if (isClosed || !state.needsAttention.contains(chatLid)) return;
    final next = <String>{...state.needsAttention}..remove(chatLid);
    emit(MonitorAttentionState(needsAttention: next));
  }

  static bool _needsAttention(MonitorEventKind kind) =>
      kind == MonitorEventKind.aiFailed ||
      kind == MonitorEventKind.flowFailed ||
      kind == MonitorEventKind.alert;

  @override
  Future<void> close() {
    unawaited(_sub?.cancel());
    return super.close();
  }
}
