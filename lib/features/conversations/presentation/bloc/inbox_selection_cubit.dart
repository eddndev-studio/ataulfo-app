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

  /// Entra al modo contextual sin seleccionar una fila todavía. Permite que el
  /// menú de la Bandeja haga descubrible la selección sin depender del long
  /// press. Las mutaciones bloquean cualquier cambio de targets.
  void begin() {
    if (state.isMutating || state.isActive) return;
    emit(state.copyWith(isActive: true, clearResult: true));
  }

  /// Alterna una fila cargada. Devuelve `false` sólo si alcanzó el límite o hay
  /// una operación en curso; la UI puede comunicar el primer caso al usuario.
  bool toggle(Conversation conversation) {
    if (state.isMutating) return false;
    final ref = InboxConversationRef.fromConversation(conversation);
    final next = Map<InboxConversationRef, Conversation>.of(state.byRef);
    if (next.remove(ref) != null) {
      emit(
        state.copyWith(
          selected: next,
          isActive: next.isNotEmpty,
          clearResult: true,
        ),
      );
      return true;
    }
    if (next.length >= maxSelection) return false;
    next[ref] = conversation;
    emit(state.copyWith(selected: next, isActive: true, clearResult: true));
    return true;
  }

  /// Selecciona las filas cargadas de la consulta, hasta [maxSelection].
  /// Devuelve `false` cuando había más targets de los que caben; aun así deja
  /// seleccionadas las primeras 50 para que la acción del usuario sí produzca
  /// un resultado y la UI pueda explicar el límite.
  bool selectVisible(Iterable<Conversation> visible) {
    if (state.isMutating) return false;
    final next = Map<InboxConversationRef, Conversation>.of(state.byRef);
    var completed = true;
    for (final conversation in visible) {
      final ref = InboxConversationRef.fromConversation(conversation);
      if (next.containsKey(ref)) {
        next[ref] = conversation;
        continue;
      }
      if (next.length >= maxSelection) {
        completed = false;
        break;
      }
      next[ref] = conversation;
    }
    emit(state.copyWith(selected: next, isActive: true, clearResult: true));
    return completed;
  }

  /// Conserva la identidad a través de reorder/refresh, actualiza los snapshots
  /// y descarta targets que ya no pertenecen a las filas cargadas de la consulta.
  void reconcileVisible(List<Conversation> visible) {
    if (state.isMutating || state.byRef.isEmpty) return;
    final current = <InboxConversationRef, Conversation>{
      for (final conversation in visible)
        InboxConversationRef.fromConversation(conversation): conversation,
    };
    final next = <InboxConversationRef, Conversation>{
      for (final ref in state.byRef.keys) ref: ?current[ref],
    };
    emit(state.copyWith(selected: next, isActive: next.isNotEmpty));
  }

  void clear() {
    if (state.isMutating || (!state.isActive && state.byRef.isEmpty)) return;
    emit(
      state.copyWith(selected: const {}, isActive: false, clearResult: true),
    );
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
    emit(state.copyWith(isActive: true, isMutating: true, clearResult: true));

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

    // El shell puede desmontarse (por ejemplo, al cerrar sesión) mientras el
    // repositorio aún resuelve la operación. El resultado sigue siendo válido
    // para quien espera el Future, pero ya no existe una UI a la cual emitirlo.
    if (isClosed) return result;

    final failures = <InboxConversationRef, Conversation>{
      for (final ref in result.failed) ref: ?state.byRef[ref],
    };
    emit(
      state.copyWith(
        selected: failures,
        isActive: failures.isNotEmpty,
        isMutating: false,
        lastResult: result,
      ),
    );
    return result;
  }
}

class InboxSelectionState {
  InboxSelectionState._({
    required Map<InboxConversationRef, Conversation> selected,
    required this.isActive,
    required this.isMutating,
    required this.lastResult,
  }) : assert(isActive || selected.isEmpty),
       byRef = Map<InboxConversationRef, Conversation>.unmodifiable(selected);

  factory InboxSelectionState.initial() => InboxSelectionState._(
    selected: const <InboxConversationRef, Conversation>{},
    isActive: false,
    isMutating: false,
    lastResult: null,
  );

  final Map<InboxConversationRef, Conversation> byRef;
  final bool isActive;
  final bool isMutating;
  final InboxBulkResult? lastResult;

  int get count => byRef.length;
  List<Conversation> get selected =>
      List<Conversation>.unmodifiable(byRef.values);

  bool contains(Conversation conversation) =>
      byRef.containsKey(InboxConversationRef.fromConversation(conversation));

  InboxSelectionState copyWith({
    Map<InboxConversationRef, Conversation>? selected,
    bool? isActive,
    bool? isMutating,
    InboxBulkResult? lastResult,
    bool clearResult = false,
  }) => InboxSelectionState._(
    selected: selected ?? byRef,
    isActive: isActive ?? this.isActive,
    isMutating: isMutating ?? this.isMutating,
    lastResult: clearResult ? null : (lastResult ?? this.lastResult),
  );
}
