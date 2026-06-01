import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/wa_label.dart';
import '../../domain/entities/wa_label_live_event.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../../domain/repositories/wa_labels_repository.dart';

/// Bloc del catálogo de etiquetas WhatsApp de un bot (S21). Se construye con el
/// `botId` (la ruta `/bots/:id/wa-labels` lo aporta), como `ConversationsBloc`.
///
/// **Realtime:** tras la carga inicial se suscribe al stream SSE `label.wa.*`
/// del bot y refleja en vivo los cambios del catálogo —EDITED (alta/edición) y
/// REMOVED (tombstone)— sin recargar; otro operador o el propio WhatsApp pueden
/// editar el catálogo. Los eventos de asociación (CHAT/MESSAGE) se ignoran aquí:
/// no tocan el catálogo. Ante una reconexión (`WaLabelReconnected`) reconcilia
/// contra la verdad HTTP, porque el stream no reproduce el tramo del corte.
///
/// El estado conserva el espejo COMPLETO (incluidos tombstones `deleted:true`);
/// la UI filtra las activas. `isRefreshing` deja que el pull-to-refresh no
/// oculte la lista mientras se refresca.
class WaLabelsBloc extends Bloc<WaLabelsEvent, WaLabelsState> {
  WaLabelsBloc({required WaLabelsRepository repo, required String botId})
    : _repo = repo,
      _botId = botId,
      super(const WaLabelsLoading()) {
    on<WaLabelsLoadRequested>(_onLoad);
    on<WaLabelsRefreshRequested>(_onRefresh);
    on<WaLabelsCatalogChanged>(_onCatalogChanged);
    on<WaLabelsReconnected>(_onReconnected);
  }

  final WaLabelsRepository _repo;
  final String _botId;

  /// El bot dueño de este catálogo. La página/sheets lo usan para las
  /// mutaciones (que cuelgan de `/bots/:botId/...`) sin recibirlo por separado.
  String get botId => _botId;

  StreamSubscription<WaLabelLiveEvent>? _liveSub;

  /// Evita refetchs solapados cuando llegan varias reconexiones seguidas.
  bool _refetching = false;

  Future<void> _onLoad(
    WaLabelsLoadRequested event,
    Emitter<WaLabelsState> emit,
  ) async {
    if (state is! WaLabelsLoading) {
      emit(const WaLabelsLoading());
    }
    try {
      final labels = await _repo.listCatalog(_botId);
      emit(WaLabelsLoaded(labels: labels, isRefreshing: false));
      // El realtime arranca DESPUÉS de pintar el catálogo: así los handlers de
      // cambios solo corren sobre un `WaLabelsLoaded`.
      _startLive();
    } on WaLabelsFailure catch (f) {
      emit(WaLabelsFailed(f));
    }
  }

  /// Abre (o reabre) la suscripción al stream en vivo. Reentrante: una recarga
  /// cancela la previa antes de abrir otra. Cada evento del stream se reinyecta
  /// como evento del bloc para que la mutación del estado viva en un solo punto.
  void _startLive() {
    _liveSub?.cancel();
    _liveSub = _repo.liveEvents(_botId).listen(
      (e) {
        switch (e) {
          case WaLabelCatalogChanged():
            add(WaLabelsCatalogChanged(e));
          case WaLabelReconnected():
            add(const WaLabelsReconnected());
          case WaChatLabelChanged():
          case WaMessageLabelChanged():
            break; // asociaciones: no afectan el catálogo
        }
      },
      // Realtime caído NO derriba el catálogo: el estado HTTP sigue válido.
      onError: (Object _) {},
    );
  }

  void _onCatalogChanged(
    WaLabelsCatalogChanged event,
    Emitter<WaLabelsState> emit,
  ) {
    final current = state;
    if (current is! WaLabelsLoaded) {
      return;
    }
    final c = event.change;
    final updated = WaLabel(
      waLabelId: c.waLabelId,
      name: c.name,
      color: c.color,
      deleted: c.removed,
    );
    final labels = List<WaLabel>.of(current.labels);
    final i = labels.indexWhere((l) => l.waLabelId == c.waLabelId);
    if (i >= 0) {
      labels[i] = updated; // edición, re-creación o tombstone de una existente
    } else if (!c.removed) {
      labels.add(updated); // alta llegada de otro dispositivo
    } else {
      return; // REMOVED de una etiqueta que no teníamos: nada que reflejar
    }
    emit(WaLabelsLoaded(labels: labels, isRefreshing: current.isRefreshing));
  }

  /// Tras reconectar, reconcilia contra la verdad HTTP (el SSE no reproduce el
  /// hueco). Best-effort: si el refetch falla, el catálogo en vivo se conserva.
  Future<void> _onReconnected(
    WaLabelsReconnected event,
    Emitter<WaLabelsState> emit,
  ) async {
    if (state is! WaLabelsLoaded || _refetching) {
      return;
    }
    _refetching = true;
    try {
      final labels = await _repo.listCatalog(_botId);
      final current = state;
      if (current is! WaLabelsLoaded) {
        return;
      }
      emit(WaLabelsLoaded(labels: labels, isRefreshing: current.isRefreshing));
    } on WaLabelsFailure {
      // Refetch best-effort: una reconexión sin red no debe derribar la lista.
    } finally {
      _refetching = false;
    }
  }

  Future<void> _onRefresh(
    WaLabelsRefreshRequested event,
    Emitter<WaLabelsState> emit,
  ) async {
    final current = state;
    if (current is! WaLabelsLoaded) {
      add(const WaLabelsLoadRequested());
      return;
    }
    emit(WaLabelsLoaded(labels: current.labels, isRefreshing: true));
    try {
      final labels = await _repo.listCatalog(_botId);
      emit(WaLabelsLoaded(labels: labels, isRefreshing: false));
    } on WaLabelsFailure catch (f) {
      emit(WaLabelsFailed(f));
    }
  }

  @override
  Future<void> close() {
    _liveSub?.cancel();
    return super.close();
  }
}

// Events --------------------------------------------------------------------

sealed class WaLabelsEvent {
  const WaLabelsEvent();
}

class WaLabelsLoadRequested extends WaLabelsEvent {
  const WaLabelsLoadRequested();
  @override
  bool operator ==(Object other) => other is WaLabelsLoadRequested;
  @override
  int get hashCode => (WaLabelsLoadRequested).hashCode;
}

class WaLabelsRefreshRequested extends WaLabelsEvent {
  const WaLabelsRefreshRequested();
  @override
  bool operator ==(Object other) => other is WaLabelsRefreshRequested;
  @override
  int get hashCode => (WaLabelsRefreshRequested).hashCode;
}

/// Un cambio del catálogo llegó por el stream en vivo (EDITED/REMOVED). El
/// handler lo aplica como upsert sobre el espejo cargado.
class WaLabelsCatalogChanged extends WaLabelsEvent {
  const WaLabelsCatalogChanged(this.change);

  final WaLabelCatalogChanged change;

  @override
  bool operator ==(Object other) =>
      other is WaLabelsCatalogChanged && other.change == change;
  @override
  int get hashCode => change.hashCode;
}

/// El stream en vivo se reconectó tras un corte: dispara la reconciliación
/// contra la verdad HTTP.
class WaLabelsReconnected extends WaLabelsEvent {
  const WaLabelsReconnected();
  @override
  bool operator ==(Object other) => other is WaLabelsReconnected;
  @override
  int get hashCode => (WaLabelsReconnected).hashCode;
}

// States --------------------------------------------------------------------

sealed class WaLabelsState {
  const WaLabelsState();
}

class WaLabelsLoading extends WaLabelsState {
  const WaLabelsLoading();
  @override
  bool operator ==(Object other) => other is WaLabelsLoading;
  @override
  int get hashCode => (WaLabelsLoading).hashCode;
}

class WaLabelsLoaded extends WaLabelsState {
  const WaLabelsLoaded({required this.labels, required this.isRefreshing});

  /// Espejo completo del catálogo (incluye tombstones `deleted:true`); la UI
  /// filtra las activas.
  final List<WaLabel> labels;

  /// Hay un refresh en vuelo (spinner sutil; la lista sigue visible).
  final bool isRefreshing;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaLabelsLoaded) return false;
    if (other.isRefreshing != isRefreshing) return false;
    if (other.labels.length != labels.length) return false;
    for (var i = 0; i < labels.length; i++) {
      if (other.labels[i] != labels[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(labels), isRefreshing);
}

class WaLabelsFailed extends WaLabelsState {
  const WaLabelsFailed(this.failure);

  final WaLabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is WaLabelsFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
