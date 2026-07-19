import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/inbox_bulk_actions.dart';
import '../../domain/entities/conversation.dart';

/// Selección y ciclo de mutación de la Bandeja, deliberadamente separados del
/// [ConversationsBloc]: consultar/paginar no debe conocer acciones masivas.
class InboxSelectionCubit extends Cubit<InboxSelectionState> {
  InboxSelectionCubit({required InboxBulkActions actions})
    : _actions = actions,
      super(InboxSelectionState.initial());

  static const int maxSelection = 50;

  final InboxBulkActions _actions;

  /// Alterna una fila cargada. Devuelve `false` sólo si alcanzó el límite o hay
  /// una operación en curso; la UI puede comunicar el primer caso al usuario.
  bool toggle(Conversation conversation) {
    if (state.isMutating) return false;
    final ref = InboxConversationRef.fromConversation(conversation);
    final next = Map<InboxConversationRef, Conversation>.of(state.byRef);
    if (next.remove(ref) != null) {
      emit(state.copyWith(selected: next, clearResult: true));
      return true;
    }
    if (next.length >= maxSelection) return false;
    next[ref] = conversation;
    emit(state.copyWith(selected: next, clearResult: true));
    return true;
  }

  /// Conserva la identidad a través de reorder/refresh, actualiza los snapshots
  /// y descarta targets que ya no pertenecen a las filas cargadas de la consulta.
  void reconcileVisible(List<Conversation> visible) {
    if (state.byRef.isEmpty) return;
    final current = <InboxConversationRef, Conversation>{
      for (final conversation in visible)
        InboxConversationRef.fromConversation(conversation): conversation,
    };
    final next = <InboxConversationRef, Conversation>{
      for (final ref in state.byRef.keys)
        if (current[ref] case final conversation?) ref: conversation,
    };
    emit(state.copyWith(selected: next));
  }

  void clear() {
    if (state.byRef.isEmpty || state.isMutating) return;
    emit(state.copyWith(selected: const {}, clearResult: true));
  }

  Future<InboxBulkResult?> addLabel(String labelId) =>
      _run((targets) => _actions.addLabel(targets, labelId));

  Future<InboxBulkResult?> removeLabel(String labelId) =>
      _run((targets) => _actions.removeLabel(targets, labelId));

  Future<InboxBulkResult?> markRead() => _run(_actions.markRead);

  Future<InboxBulkResult?> clearHistory() => _run(_actions.clearHistory);

  Future<InboxBulkResult?> _run(
    Future<InboxBulkResult> Function(List<Conversation>) operation,
  ) async {
    if (state.isMutating || state.byRef.isEmpty) return null;
    final targets = state.selected;
    final attempted = targets
        .map(InboxConversationRef.fromConversation)
        .toSet();
    emit(state.copyWith(isMutating: true, clearResult: true));

    late final InboxBulkResult result;
    try {
      result = await operation(targets);
    } catch (_) {
      result = InboxBulkResult(
        attempted: attempted,
        succeeded: const <InboxConversationRef>{},
        failed: attempted,
      );
    }

    final failures = <InboxConversationRef, Conversation>{
      for (final ref in result.failed)
        if (state.byRef[ref] case final conversation?) ref: conversation,
    };
    emit(
      state.copyWith(selected: failures, isMutating: false, lastResult: result),
    );
    return result;
  }
}

class InboxSelectionState {
  InboxSelectionState._({
    required Map<InboxConversationRef, Conversation> selected,
    required this.isMutating,
    required this.lastResult,
  }) : byRef = Map<InboxConversationRef, Conversation>.unmodifiable(selected);

  factory InboxSelectionState.initial() => InboxSelectionState._(
    selected: const <InboxConversationRef, Conversation>{},
    isMutating: false,
    lastResult: null,
  );

  final Map<InboxConversationRef, Conversation> byRef;
  final bool isMutating;
  final InboxBulkResult? lastResult;

  int get count => byRef.length;
  List<Conversation> get selected =>
      List<Conversation>.unmodifiable(byRef.values);

  bool contains(Conversation conversation) =>
      byRef.containsKey(InboxConversationRef.fromConversation(conversation));

  InboxSelectionState copyWith({
    Map<InboxConversationRef, Conversation>? selected,
    bool? isMutating,
    InboxBulkResult? lastResult,
    bool clearResult = false,
  }) => InboxSelectionState._(
    selected: selected ?? byRef,
    isMutating: isMutating ?? this.isMutating,
    lastResult: clearResult ? null : (lastResult ?? this.lastResult),
  );
}
