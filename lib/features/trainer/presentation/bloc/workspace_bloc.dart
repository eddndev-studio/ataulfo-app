import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_doc.dart';
import '../../domain/failures/trainer_failure.dart';
import '../../domain/repositories/trainer_repositories.dart';

sealed class WorkspaceEvent {
  const WorkspaceEvent();
}

final class WorkspaceLoadRequested extends WorkspaceEvent {
  const WorkspaceLoadRequested();
}

final class WorkspaceDocCreated extends WorkspaceEvent {
  const WorkspaceDocCreated({required this.name, required this.content});

  final String name;
  final String content;
}

final class WorkspaceDocUpdated extends WorkspaceEvent {
  const WorkspaceDocUpdated({
    required this.name,
    required this.content,
    required this.version,
  });

  final String name;
  final String content;
  final int version;
}

final class WorkspaceDocDeleted extends WorkspaceEvent {
  const WorkspaceDocDeleted({required this.name, required this.version});

  final String name;
  final int version;
}

sealed class WorkspaceState {
  const WorkspaceState();
}

final class WorkspaceLoading extends WorkspaceState {
  const WorkspaceLoading();

  @override
  bool operator ==(Object other) => other is WorkspaceLoading;

  @override
  int get hashCode => (WorkspaceLoading).hashCode;
}

final class WorkspaceFailed extends WorkspaceState {
  const WorkspaceFailed(this.failure);

  final TrainerFailure failure;
}

final class WorkspaceLoaded extends WorkspaceState {
  const WorkspaceLoaded({
    required this.docs,
    required this.mutating,
    this.mutationFailure,
  });

  final List<WorkspaceDoc> docs;
  final bool mutating;

  /// Fallo de la ÚLTIMA mutación (el listado sigue usable); el copy de la
  /// UI ramifica: 409 ⇒ "otro editor (panel o entrenador) cambió el doc".
  final TrainerFailure? mutationFailure;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceLoaded &&
      listEquals(other.docs, docs) &&
      other.mutating == mutating &&
      other.mutationFailure == mutationFailure;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(docs), mutating, mutationFailure);
}

/// Cuaderno del workspace (mismo ciclo mutación→recarga que NotesBloc:
/// snapshot ante fallo de mutación, Failed global solo si la RECARGA
/// posterior falla).
class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc({required WorkspaceRepository repo, required String templateId})
    : _repo = repo,
      _templateId = templateId,
      super(const WorkspaceLoading()) {
    on<WorkspaceLoadRequested>(_onLoad);
    on<WorkspaceDocCreated>(
      (e, emit) => _mutate(
        emit,
        () => _repo.createDoc(
          templateId: _templateId,
          name: e.name,
          content: e.content,
        ),
      ),
    );
    on<WorkspaceDocUpdated>(
      (e, emit) => _mutate(
        emit,
        () => _repo.updateDoc(
          templateId: _templateId,
          name: e.name,
          content: e.content,
          version: e.version,
        ),
      ),
    );
    on<WorkspaceDocDeleted>(
      (e, emit) => _mutate(
        emit,
        () => _repo.deleteDoc(
          templateId: _templateId,
          name: e.name,
          version: e.version,
        ),
      ),
    );
  }

  final WorkspaceRepository _repo;
  final String _templateId;

  Future<void> _onLoad(
    WorkspaceLoadRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    emit(const WorkspaceLoading());
    try {
      final docs = await _repo.listDocs(templateId: _templateId);
      emit(WorkspaceLoaded(docs: docs, mutating: false));
    } on TrainerFailure catch (f) {
      emit(WorkspaceFailed(f));
    }
  }

  Future<void> _mutate(
    Emitter<WorkspaceState> emit,
    Future<Object?> Function() effect,
  ) async {
    final current = state;
    if (current is! WorkspaceLoaded || current.mutating) return;
    emit(WorkspaceLoaded(docs: current.docs, mutating: true));
    try {
      await effect();
    } on TrainerFailure catch (f) {
      emit(
        WorkspaceLoaded(docs: current.docs, mutating: false, mutationFailure: f),
      );
      return;
    }
    try {
      final docs = await _repo.listDocs(templateId: _templateId);
      emit(WorkspaceLoaded(docs: docs, mutating: false));
    } on TrainerFailure catch (f) {
      // La mutación SÍ aplicó pero la recarga falló: estado global.
      emit(WorkspaceFailed(f));
    }
  }
}
