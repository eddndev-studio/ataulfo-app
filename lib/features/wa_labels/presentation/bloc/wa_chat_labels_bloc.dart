import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../conversations/domain/entities/conversation.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/entities/wa_label_live_event.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../../domain/repositories/wa_labels_repository.dart';

/// Bloc de las etiquetas WhatsApp de UN chat (S21). Vive atado al sheet de
/// etiquetas de una conversación: lista el catálogo activo del bot y marca
/// cuáles están asociadas a este `chatLid`. El toggle empuja a WhatsApp
/// (`labelChat`); el `kind` (DM/GROUP) viaja en el body porque arma el JID.
///
/// **Realtime:** se suscribe al stream `label.wa.*` y refleja en vivo las
/// asociaciones de ESTE chat (eventos CHAT con el mismo `chatLid`); el resto se
/// ignora. Ante reconexión reconcilia contra HTTP. Espeja el patrón de
/// `WaLabelsBloc` (mutación con snapshot + realtime).
class WaChatLabelsBloc extends Bloc<WaChatLabelsEvent, WaChatLabelsState> {
  WaChatLabelsBloc({
    required WaLabelsRepository repo,
    required String botId,
    required String chatLid,
    required ConversationKind kind,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       _kind = kind,
       super(const WaChatLabelsLoading()) {
    on<WaChatLabelsLoadRequested>(_onLoad);
    on<WaChatLabelsToggleRequested>(_onToggle);
    on<WaChatLabelsLive>(_onLive);
    on<WaChatLabelsReconnected>(_onReconnected);
  }

  final WaLabelsRepository _repo;
  final String _botId;
  final String _chatLid;
  final ConversationKind _kind;

  StreamSubscription<WaLabelLiveEvent>? _liveSub;
  bool _refetching = false;

  Future<void> _onLoad(
    WaChatLabelsLoadRequested event,
    Emitter<WaChatLabelsState> emit,
  ) async {
    if (state is! WaChatLabelsLoading) {
      emit(const WaChatLabelsLoading());
    }
    try {
      // Secuencial (no pre-iniciado): si listCatalog lanza, listChatAssocs no
      // arranca, así que no quedan futures con error sin capturar.
      final catalog = await _repo.listCatalog(_botId);
      final assocs = await _repo.listChatAssocs(_botId);
      emit(
        WaChatLabelsLoaded(
          catalog: <WaLabel>[
            for (final l in catalog)
              if (!l.deleted) l,
          ],
          associated: <String>{
            for (final a in assocs)
              if (a.chatLid == _chatLid && a.labeled) a.waLabelId,
          },
        ),
      );
      _startLive();
    } on WaLabelsFailure catch (f) {
      emit(WaChatLabelsFailed(f));
    }
  }

  void _startLive() {
    _liveSub?.cancel();
    _liveSub = _repo.liveEvents(_botId).listen((e) {
      switch (e) {
        case WaChatLabelChanged() when e.chatLid == _chatLid:
          add(WaChatLabelsLive(e));
        case WaLabelReconnected():
          add(const WaChatLabelsReconnected());
        case WaChatLabelChanged():
        case WaLabelCatalogChanged():
        case WaMessageLabelChanged():
          break; // otro chat, o catálogo/mensaje: no afecta este sheet
      }
    }, onError: (Object _) {});
  }

  Future<void> _onToggle(
    WaChatLabelsToggleRequested event,
    Emitter<WaChatLabelsState> emit,
  ) async {
    final snap = _snapshotOf(state);
    if (snap == null) {
      return;
    }
    emit(WaChatLabelsMutating(catalog: snap.$1, associated: snap.$2));
    try {
      await _repo.labelChat(
        botId: _botId,
        waLabelId: event.waLabelId,
        chatLid: _chatLid,
        kind: _kind,
        labeled: event.associate,
      );
      final next = Set<String>.of(snap.$2);
      if (event.associate) {
        next.add(event.waLabelId);
      } else {
        next.remove(event.waLabelId);
      }
      emit(WaChatLabelsLoaded(catalog: snap.$1, associated: next));
    } on WaLabelsFailure catch (f) {
      emit(
        WaChatLabelsMutationFailed(
          catalog: snap.$1,
          associated: snap.$2,
          failure: f,
        ),
      );
    }
  }

  void _onLive(WaChatLabelsLive event, Emitter<WaChatLabelsState> emit) {
    final current = state;
    final snap = _snapshotOf(current);
    if (snap == null) {
      return;
    }
    final ev = event.change;
    // El catálogo no se reconcilia en vivo (solo en reconexión/reapertura): un
    // evento CHAT de una etiqueta que aún no está en el catálogo se ignora para
    // no dejar una asociación "fantasma" que el sheet no puede pintar ni togglear.
    if (!snap.$1.any((l) => l.waLabelId == ev.waLabelId)) {
      return;
    }
    final next = Set<String>.of(snap.$2);
    if (ev.labeled) {
      next.add(ev.waLabelId);
    } else {
      next.remove(ev.waLabelId);
    }
    emit(_reemit(current, snap.$1, next));
  }

  Future<void> _onReconnected(
    WaChatLabelsReconnected event,
    Emitter<WaChatLabelsState> emit,
  ) async {
    final snap = _snapshotOf(state);
    if (snap == null || _refetching) {
      return;
    }
    _refetching = true;
    try {
      // Reconcilia AMBOS contra la verdad HTTP: el catálogo (otra etiqueta pudo
      // crearse/editarse/borrarse durante el corte) y las asociaciones.
      final catalog = await _repo.listCatalog(_botId);
      final assocs = await _repo.listChatAssocs(_botId);
      final current = state;
      if (_snapshotOf(current) == null) {
        return;
      }
      emit(
        _reemit(
          current,
          <WaLabel>[
            for (final l in catalog)
              if (!l.deleted) l,
          ],
          <String>{
            for (final a in assocs)
              if (a.chatLid == _chatLid && a.labeled) a.waLabelId,
          },
        ),
      );
    } on WaLabelsFailure {
      // best-effort
    } finally {
      _refetching = false;
    }
  }

  /// `(catalog, associated)` de un estado que los lleva, o `null`.
  static (List<WaLabel>, Set<String>)? _snapshotOf(WaChatLabelsState s) =>
      switch (s) {
        WaChatLabelsLoaded(:final catalog, :final associated) => (
          catalog,
          associated,
        ),
        WaChatLabelsMutationFailed(:final catalog, :final associated) => (
          catalog,
          associated,
        ),
        _ => null,
      };

  /// Re-emite la misma variante con un set nuevo (preserva el failure de
  /// MutationFailed para no cerrar el sheet de error en un parche de realtime).
  static WaChatLabelsState _reemit(
    WaChatLabelsState current,
    List<WaLabel> catalog,
    Set<String> associated,
  ) => switch (current) {
    WaChatLabelsMutationFailed(:final failure) => WaChatLabelsMutationFailed(
      catalog: catalog,
      associated: associated,
      failure: failure,
    ),
    _ => WaChatLabelsLoaded(catalog: catalog, associated: associated),
  };

  @override
  Future<void> close() {
    _liveSub?.cancel();
    return super.close();
  }
}

// Events --------------------------------------------------------------------

sealed class WaChatLabelsEvent {
  const WaChatLabelsEvent();
}

class WaChatLabelsLoadRequested extends WaChatLabelsEvent {
  const WaChatLabelsLoadRequested();
  @override
  bool operator ==(Object other) => other is WaChatLabelsLoadRequested;
  @override
  int get hashCode => (WaChatLabelsLoadRequested).hashCode;
}

class WaChatLabelsToggleRequested extends WaChatLabelsEvent {
  const WaChatLabelsToggleRequested({
    required this.waLabelId,
    required this.associate,
  });

  final String waLabelId;
  final bool associate;

  @override
  bool operator ==(Object other) =>
      other is WaChatLabelsToggleRequested &&
      other.waLabelId == waLabelId &&
      other.associate == associate;
  @override
  int get hashCode => Object.hash(waLabelId, associate);
}

class WaChatLabelsLive extends WaChatLabelsEvent {
  const WaChatLabelsLive(this.change);

  final WaChatLabelChanged change;

  @override
  bool operator ==(Object other) =>
      other is WaChatLabelsLive && other.change == change;
  @override
  int get hashCode => change.hashCode;
}

class WaChatLabelsReconnected extends WaChatLabelsEvent {
  const WaChatLabelsReconnected();
  @override
  bool operator ==(Object other) => other is WaChatLabelsReconnected;
  @override
  int get hashCode => (WaChatLabelsReconnected).hashCode;
}

// States --------------------------------------------------------------------

sealed class WaChatLabelsState {
  const WaChatLabelsState();
}

class WaChatLabelsLoading extends WaChatLabelsState {
  const WaChatLabelsLoading();
  @override
  bool operator ==(Object other) => other is WaChatLabelsLoading;
  @override
  int get hashCode => (WaChatLabelsLoading).hashCode;
}

class WaChatLabelsLoaded extends WaChatLabelsState {
  const WaChatLabelsLoaded({required this.catalog, required this.associated});

  final List<WaLabel> catalog;
  final Set<String> associated;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaChatLabelsLoaded) return false;
    return _listEq(other.catalog, catalog) &&
        _setEq(other.associated, associated);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(catalog), Object.hashAllUnordered(associated));
}

class WaChatLabelsFailed extends WaChatLabelsState {
  const WaChatLabelsFailed(this.failure);

  final WaLabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is WaChatLabelsFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

class WaChatLabelsMutating extends WaChatLabelsState {
  const WaChatLabelsMutating({required this.catalog, required this.associated});

  final List<WaLabel> catalog;
  final Set<String> associated;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaChatLabelsMutating) return false;
    return _listEq(other.catalog, catalog) &&
        _setEq(other.associated, associated);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(catalog), Object.hashAllUnordered(associated));
}

class WaChatLabelsMutationFailed extends WaChatLabelsState {
  const WaChatLabelsMutationFailed({
    required this.catalog,
    required this.associated,
    required this.failure,
  });

  final List<WaLabel> catalog;
  final Set<String> associated;
  final WaLabelsFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WaChatLabelsMutationFailed) return false;
    return other.failure == failure &&
        _listEq(other.catalog, catalog) &&
        _setEq(other.associated, associated);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(catalog),
    Object.hashAllUnordered(associated),
    failure,
  );
}

bool _listEq(List<WaLabel> a, List<WaLabel> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEq(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
