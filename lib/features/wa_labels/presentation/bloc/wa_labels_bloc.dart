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
    on<WaLabelsAddRequested>(_onAdd);
    on<WaLabelsUpdateRequested>(_onUpdate);
    on<WaLabelsDeleteRequested>(_onDelete);
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
    final labels = List<WaLabel>.of(current.labels);
    final i = labels.indexWhere((l) => l.waLabelId == c.waLabelId);
    if (i >= 0) {
      // REMOVED conserva la identidad del espejo (el evento puede traer name
      // vacío; el espejo del backend mantiene name/color en el tombstone).
      // EDITED reescribe name/color con el estado fundido del evento.
      labels[i] = c.removed
          ? labels[i].copyWith(deleted: true)
          : WaLabel(
              waLabelId: c.waLabelId,
              name: c.name,
              color: c.color,
              deleted: false,
            );
    } else if (!c.removed) {
      // Alta llegada de otro dispositivo.
      labels.add(
        WaLabel(
          waLabelId: c.waLabelId,
          name: c.name,
          color: c.color,
          deleted: false,
        ),
      );
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

  Future<void> _onAdd(
    WaLabelsAddRequested event,
    Emitter<WaLabelsState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      final created = await _repo.createLabel(
        botId: _botId,
        name: event.name,
        color: event.color,
      );
      return _upsert(snapshot, created);
    });
  }

  Future<void> _onUpdate(
    WaLabelsUpdateRequested event,
    Emitter<WaLabelsState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      final updated = await _repo.updateLabel(
        botId: _botId,
        waLabelId: event.waLabelId,
        name: event.name,
        color: event.color,
      );
      return _upsert(snapshot, updated);
    });
  }

  Future<void> _onDelete(
    WaLabelsDeleteRequested event,
    Emitter<WaLabelsState> emit,
  ) async {
    await _runMutation(emit, (snapshot) async {
      await _repo.deleteLabel(botId: _botId, waLabelId: event.waLabelId);
      return snapshot
          .map(
            (l) =>
                l.waLabelId == event.waLabelId ? l.copyWith(deleted: true) : l,
          )
          .toList(growable: false);
    });
  }

  /// Orquesta una mutación del catálogo. Reusa el snapshot del último estado
  /// válido (`Loaded` o `MutationFailed`); desde `Loading`/`Mutating`/`Failed`
  /// ignora — no hay snapshot fiable. El espejo se aplica OPTIMISTA con el
  /// resultado de la mutación: el catálogo del backend se reconcilia por el eco
  /// SSE entrante (no por la respuesta HTTP), así que un refetch inmediato no lo
  /// vería; el upsert idempotente hace que el eco posterior sea inocuo.
  Future<void> _runMutation(
    Emitter<WaLabelsState> emit,
    Future<List<WaLabel>> Function(List<WaLabel> snapshot) mutate,
  ) async {
    final current = state;
    final List<WaLabel> snapshot;
    if (current is WaLabelsLoaded) {
      snapshot = current.labels;
    } else if (current is WaLabelsMutationFailed) {
      snapshot = current.labels;
    } else {
      return;
    }

    emit(WaLabelsMutating(snapshot));
    try {
      final next = await mutate(snapshot);
      emit(WaLabelsLoaded(labels: next, isRefreshing: false));
    } on WaLabelsFailure catch (f) {
      emit(WaLabelsMutationFailed(snapshot, f));
    }
  }

  static List<WaLabel> _upsert(List<WaLabel> list, WaLabel label) {
    final out = List<WaLabel>.of(list);
    final i = out.indexWhere((l) => l.waLabelId == label.waLabelId);
    if (i >= 0) {
      out[i] = label;
    } else {
      out.add(label);
    }
    return out;
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

/// Pide crear una etiqueta (el servidor asigna el id y empuja a WhatsApp).
class WaLabelsAddRequested extends WaLabelsEvent {
  const WaLabelsAddRequested({required this.name, required this.color});

  final String name;
  final int color;

  @override
  bool operator ==(Object other) =>
      other is WaLabelsAddRequested &&
      other.name == name &&
      other.color == color;
  @override
  int get hashCode => Object.hash(name, color);
}

/// Pide editar una etiqueta por id (empuja a WhatsApp).
class WaLabelsUpdateRequested extends WaLabelsEvent {
  const WaLabelsUpdateRequested({
    required this.waLabelId,
    required this.name,
    required this.color,
  });

  final String waLabelId;
  final String name;
  final int color;

  @override
  bool operator ==(Object other) =>
      other is WaLabelsUpdateRequested &&
      other.waLabelId == waLabelId &&
      other.name == name &&
      other.color == color;
  @override
  int get hashCode => Object.hash(waLabelId, name, color);
}

/// Pide borrar una etiqueta por id (tombstone; empuja a WhatsApp).
class WaLabelsDeleteRequested extends WaLabelsEvent {
  const WaLabelsDeleteRequested({required this.waLabelId});

  final String waLabelId;

  @override
  bool operator ==(Object other) =>
      other is WaLabelsDeleteRequested && other.waLabelId == waLabelId;
  @override
  int get hashCode => waLabelId.hashCode;
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

/// Una mutación del catálogo está en vuelo. Lleva el snapshot vigente para que
/// la UI siga mostrando la lista mientras el sheet dibuja su spinner; al
/// terminar pasa a `Loaded` (éxito, espejo optimista) o a `MutationFailed`.
class WaLabelsMutating extends WaLabelsState {
  const WaLabelsMutating(this.labels);

  final List<WaLabel> labels;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaLabelsMutating) return false;
    if (other.labels.length != labels.length) return false;
    for (var i = 0; i < labels.length; i++) {
      if (other.labels[i] != labels[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(labels);
}

/// Mutación fallida que preserva el snapshot pre-mutación. El sheet abierto
/// interpreta el failure (Invalid / NotConnected / Upstream / …) y lo muestra;
/// el resto de la página sigue viendo la lista. Una nueva mutación desde aquí
/// reusa el snapshot como base.
class WaLabelsMutationFailed extends WaLabelsState {
  const WaLabelsMutationFailed(this.labels, this.failure);

  final List<WaLabel> labels;
  final WaLabelsFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaLabelsMutationFailed) return false;
    if (other.failure != failure) return false;
    if (other.labels.length != labels.length) return false;
    for (var i = 0; i < labels.length; i++) {
      if (other.labels[i] != labels[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(failure, Object.hashAll(labels));
}
