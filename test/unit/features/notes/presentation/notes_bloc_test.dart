import 'package:ataulfo/features/notes/domain/entities/note.dart';
import 'package:ataulfo/features/notes/domain/failures/notes_failure.dart';
import 'package:ataulfo/features/notes/domain/repositories/notes_repository.dart';
import 'package:ataulfo/features/notes/presentation/bloc/notes_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NotesRepository {}

final _note = Note(
  id: 'n1',
  content: 'cliente VIP',
  tags: const <String>['vip'],
  color: '',
  isAiCreated: false,
  version: 1,
  updatedAt: DateTime.utc(2026, 6, 1),
);

final _aiNote = Note(
  id: 'n2',
  content: 'prefiere tardes',
  tags: const <String>[],
  color: '',
  isAiCreated: true,
  version: 1,
  updatedAt: DateTime.utc(2026, 6, 2),
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  NotesBloc build() => NotesBloc(repo: repo, botId: 'b1', chatLid: '12@lid');

  group('NotesBloc — load', () {
    test('estado inicial = Loading', () {
      final bloc = build();
      expect(bloc.state, const NotesLoading());
      bloc.close();
    });

    blocTest<NotesBloc, NotesState>(
      'LoadRequested ok → Loaded(notes del chat)',
      build: () {
        when(
          () => repo.listChatNotes(botId: 'b1', chatLid: '12@lid'),
        ).thenAnswer((_) async => <Note>[_note, _aiNote]);
        return build();
      },
      act: (bloc) => bloc.add(const NotesLoadRequested()),
      expect: () => <NotesState>[
        NotesLoaded(<Note>[_note, _aiNote]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'LoadRequested falla → Failed(failure)',
      build: () {
        when(
          () => repo.listChatNotes(botId: 'b1', chatLid: '12@lid'),
        ).thenAnswer((_) => Future<List<Note>>.error(
              const NotesServerFailure(),
            ));
        return build();
      },
      act: (bloc) => bloc.add(const NotesLoadRequested()),
      expect: () => const <NotesState>[NotesFailed(NotesServerFailure())],
    );
  });

  group('NotesBloc — create', () {
    blocTest<NotesBloc, NotesState>(
      'CreateRequested ok → Mutating → recarga → Loaded',
      build: () {
        when(
          () => repo.createNote(
            botId: 'b1',
            chatLid: '12@lid',
            content: 'nueva',
            tags: const <String>[],
            color: '',
          ),
        ).thenAnswer((_) async => _note);
        when(
          () => repo.listChatNotes(botId: 'b1', chatLid: '12@lid'),
        ).thenAnswer((_) async => <Note>[_note]);
        return build();
      },
      seed: () => const NotesLoaded(<Note>[]),
      act: (bloc) => bloc.add(
        const NotesCreateRequested(content: 'nueva', tags: <String>[], color: ''),
      ),
      expect: () => <NotesState>[
        const NotesMutating(<Note>[]),
        NotesLoaded(<Note>[_note]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'create 422 → MutationFailed conservando las notas previas',
      build: () {
        when(
          () => repo.createNote(
            botId: any(named: 'botId'),
            chatLid: any(named: 'chatLid'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            color: any(named: 'color'),
          ),
        ).thenAnswer((_) => Future<Note>.error(const NotesValidationFailure()));
        return build();
      },
      seed: () => NotesLoaded(<Note>[_note]),
      act: (bloc) => bloc.add(
        const NotesCreateRequested(content: '', tags: <String>[], color: ''),
      ),
      expect: () => <NotesState>[
        NotesMutating(<Note>[_note]),
        NotesMutationFailed(<Note>[_note], const NotesValidationFailure()),
      ],
    );
  });

  group('NotesBloc — update/delete', () {
    blocTest<NotesBloc, NotesState>(
      'UpdateRequested 409 → MutationFailed(Conflict)',
      build: () {
        when(
          () => repo.updateNote(
            id: any(named: 'id'),
            version: any(named: 'version'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            color: any(named: 'color'),
          ),
        ).thenAnswer((_) => Future<Note>.error(const NotesConflictFailure()));
        return build();
      },
      seed: () => NotesLoaded(<Note>[_note]),
      act: (bloc) => bloc.add(
        const NotesUpdateRequested(
          id: 'n1',
          version: 1,
          content: 'editada',
          tags: <String>[],
          color: '',
        ),
      ),
      expect: () => <NotesState>[
        NotesMutating(<Note>[_note]),
        NotesMutationFailed(<Note>[_note], const NotesConflictFailure()),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'DeleteRequested ok → Mutating → recarga sin la nota',
      build: () {
        when(
          () => repo.deleteNote(id: 'n1', version: 1),
        ).thenAnswer((_) async {});
        when(
          () => repo.listChatNotes(botId: 'b1', chatLid: '12@lid'),
        ).thenAnswer((_) async => const <Note>[]);
        return build();
      },
      seed: () => NotesLoaded(<Note>[_note]),
      act: (bloc) => bloc.add(const NotesDeleteRequested(id: 'n1', version: 1)),
      expect: () => <NotesState>[
        NotesMutating(<Note>[_note]),
        const NotesLoaded(<Note>[]),
      ],
      verify: (_) {
        verify(() => repo.deleteNote(id: 'n1', version: 1)).called(1);
      },
    );
  });
}
