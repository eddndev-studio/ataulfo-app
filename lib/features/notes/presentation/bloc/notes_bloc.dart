import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/note.dart';
import '../../domain/failures/notes_failure.dart';
import '../../domain/repositories/notes_repository.dart';

/// Bloc del cuaderno de notas de UN chat (S14). Vida atada al sheet del
/// hilo: se construye con (botId, chatLid) y arranca en Loading.
///
/// Toda mutación exitosa recarga el listado (la version del CAS avanzó y
/// otro editor —operador o IA— pudo escribir en paralelo); una fallida
/// preserva el snapshot para que el sheet muestre el copy sin perder la
/// lista.
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc({
    required NotesRepository repo,
    required String botId,
    required String chatLid,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       super(const NotesLoading()) {
    on<NotesLoadRequested>(_onLoad);
    on<NotesCreateRequested>(_onCreate);
    on<NotesUpdateRequested>(_onUpdate);
    on<NotesDeleteRequested>(_onDelete);
  }

  final NotesRepository _repo;
  final String _botId;
  final String _chatLid;

  Future<void> _onLoad(
    NotesLoadRequested event,
    Emitter<NotesState> emit,
  ) async {
    if (state is! NotesLoading) {
      emit(const NotesLoading());
    }
    try {
      final notes = await _repo.listChatNotes(
        botId: _botId,
        chatLid: _chatLid,
      );
      emit(NotesLoaded(notes));
    } on NotesFailure catch (f) {
      emit(NotesFailed(f));
    }
  }

  /// Snapshot de notas visible desde el que una mutación puede partir.
  List<Note>? get _snapshot => switch (state) {
    NotesLoaded(:final notes) => notes,
    NotesMutationFailed(:final notes) => notes,
    _ => null,
  };

  Future<void> _onCreate(
    NotesCreateRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _mutate(
      emit,
      () => _repo.createNote(
        botId: _botId,
        chatLid: _chatLid,
        content: event.content,
        tags: event.tags,
        color: event.color,
      ),
    );
  }

  Future<void> _onUpdate(
    NotesUpdateRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _mutate(
      emit,
      () => _repo.updateNote(
        id: event.id,
        version: event.version,
        content: event.content,
        tags: event.tags,
        color: event.color,
      ),
    );
  }

  Future<void> _onDelete(
    NotesDeleteRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _mutate(
      emit,
      () => _repo.deleteNote(id: event.id, version: event.version),
    );
  }

  /// Ciclo común de las tres mutaciones: Mutating(snapshot) → efecto →
  /// recarga (Loaded fresco) o MutationFailed(snapshot, failure).
  Future<void> _mutate(
    Emitter<NotesState> emit,
    Future<Object?> Function() effect,
  ) async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      // Desde Loading/Failed no hay lista estable sobre la que mutar.
      return;
    }
    emit(NotesMutating(snapshot));
    try {
      await effect();
    } on NotesFailure catch (f) {
      emit(NotesMutationFailed(snapshot, f));
      return;
    }
    try {
      final notes = await _repo.listChatNotes(
        botId: _botId,
        chatLid: _chatLid,
      );
      emit(NotesLoaded(notes));
    } on NotesFailure catch (f) {
      // La mutación persistió pero el refetch falló: sin verdad fresca,
      // mejor Failed global que un snapshot obsoleto editable.
      emit(NotesFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class NotesEvent {
  const NotesEvent();
}

class NotesLoadRequested extends NotesEvent {
  const NotesLoadRequested();

  @override
  bool operator ==(Object other) => other is NotesLoadRequested;
  @override
  int get hashCode => (NotesLoadRequested).hashCode;
}

class NotesCreateRequested extends NotesEvent {
  const NotesCreateRequested({
    required this.content,
    required this.tags,
    required this.color,
  });

  final String content;
  final List<String> tags;
  final String color;

  @override
  bool operator ==(Object other) =>
      other is NotesCreateRequested &&
      other.content == content &&
      other.color == color &&
      _sameTags(other.tags, tags);
  @override
  int get hashCode => Object.hash(content, color, Object.hashAll(tags));
}

class NotesUpdateRequested extends NotesEvent {
  const NotesUpdateRequested({
    required this.id,
    required this.version,
    required this.content,
    required this.tags,
    required this.color,
  });

  final String id;
  final int version;
  final String content;
  final List<String> tags;
  final String color;

  @override
  bool operator ==(Object other) =>
      other is NotesUpdateRequested &&
      other.id == id &&
      other.version == version &&
      other.content == content &&
      other.color == color &&
      _sameTags(other.tags, tags);
  @override
  int get hashCode =>
      Object.hash(id, version, content, color, Object.hashAll(tags));
}

class NotesDeleteRequested extends NotesEvent {
  const NotesDeleteRequested({required this.id, required this.version});

  final String id;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is NotesDeleteRequested &&
      other.id == id &&
      other.version == version;
  @override
  int get hashCode => Object.hash(id, version);
}

bool _sameTags(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// States --------------------------------------------------------------------

sealed class NotesState {
  const NotesState();
}

class NotesLoading extends NotesState {
  const NotesLoading();

  @override
  bool operator ==(Object other) => other is NotesLoading;
  @override
  int get hashCode => (NotesLoading).hashCode;
}

class NotesLoaded extends NotesState {
  const NotesLoaded(this.notes);

  final List<Note> notes;

  @override
  bool operator ==(Object other) =>
      other is NotesLoaded && _sameNotes(other.notes, notes);
  @override
  int get hashCode => Object.hashAll(notes);
}

class NotesMutating extends NotesState {
  const NotesMutating(this.notes);

  final List<Note> notes;

  @override
  bool operator ==(Object other) =>
      other is NotesMutating && _sameNotes(other.notes, notes);
  @override
  int get hashCode => Object.hashAll(notes);
}

class NotesMutationFailed extends NotesState {
  const NotesMutationFailed(this.notes, this.failure);

  final List<Note> notes;
  final NotesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is NotesMutationFailed &&
      other.failure == failure &&
      _sameNotes(other.notes, notes);
  @override
  int get hashCode => Object.hash(failure, Object.hashAll(notes));
}

class NotesFailed extends NotesState {
  const NotesFailed(this.failure);

  final NotesFailure failure;

  @override
  bool operator ==(Object other) =>
      other is NotesFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

bool _sameNotes(List<Note> a, List<Note> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
