import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/notes/domain/entities/note.dart';
import 'package:ataulfo/features/notes/domain/failures/notes_failure.dart';
import 'package:ataulfo/features/notes/presentation/bloc/notes_bloc.dart';
import 'package:ataulfo/features/notes/presentation/widgets/notes_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotesBloc extends MockBloc<NotesEvent, NotesState>
    implements NotesBloc {}

final _operatorNote = Note(
  id: 'n1',
  content: 'Pidió factura con RFC',
  tags: const <String>['fiscal'],
  color: '#3b82f6',
  isAiCreated: false,
  version: 1,
  updatedAt: DateTime.utc(2026, 6, 1, 10),
);

final _aiNote = Note(
  id: 'n2',
  content: 'Prefiere entregas por la tarde',
  tags: const <String>[],
  color: '',
  isAiCreated: true,
  version: 1,
  updatedAt: DateTime.utc(2026, 6, 2, 9),
);

void main() {
  late _MockNotesBloc bloc;

  setUp(() {
    bloc = _MockNotesBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<NotesBloc>.value(
        value: bloc,
        child: const NotesSheet(),
      ),
    ),
  );

  testWidgets('Loaded: pinta las notas con contenido y tags', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(NotesLoaded(<Note>[_operatorNote, _aiNote]));

    await tester.pumpWidget(host());

    expect(find.text('Pidió factura con RFC'), findsOneWidget);
    expect(find.text('Prefiere entregas por la tarde'), findsOneWidget);
    expect(find.text('fiscal'), findsOneWidget);
  });

  testWidgets('la nota de IA lleva badge "IA"; la humana no', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(NotesLoaded(<Note>[_operatorNote, _aiNote]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notes_sheet.ai_badge.n2')), findsOneWidget);
    expect(find.byKey(const Key('notes_sheet.ai_badge.n1')), findsNothing);
  });

  testWidgets('vacío: empty state + botón de nueva nota', (tester) async {
    when(() => bloc.state).thenReturn(const NotesLoaded(<Note>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notes_sheet.empty')), findsOneWidget);
    expect(find.byKey(const Key('notes_sheet.new_button')), findsOneWidget);
  });

  testWidgets('Failed: copy de error + botón reintentar recarga', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotesFailed(NotesServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notes_sheet.failed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notes_sheet.retry')));
    verify(() => bloc.add(const NotesLoadRequested())).called(1);
  });

  testWidgets('MutationFailed por conflicto: copy "recarga" visible', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      NotesMutationFailed(<Note>[_operatorNote], const NotesConflictFailure()),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notes_sheet.error')), findsOneWidget);
    // La lista sigue visible (el snapshot no se pierde).
    expect(find.text('Pidió factura con RFC'), findsOneWidget);
  });
}
