import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/notes/domain/entities/note.dart';
import 'package:ataulfo/features/notes/presentation/bloc/notes_bloc.dart';
import 'package:ataulfo/features/notes/presentation/widgets/note_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotesBloc extends MockBloc<NotesEvent, NotesState>
    implements NotesBloc {}

final _existing = Note(
  id: 'n1',
  content: 'Pidió factura',
  tags: const <String>['fiscal', 'urgente'],
  color: '#3b82f6',
  isAiCreated: false,
  version: 2,
  updatedAt: DateTime.utc(2026, 6, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NotesLoadRequested());
  });

  late _MockNotesBloc bloc;

  setUp(() {
    bloc = _MockNotesBloc();
    when(() => bloc.state).thenReturn(const NotesLoaded(<Note>[]));
  });

  Widget host({Note? note}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<NotesBloc>.value(
        value: bloc,
        child: NoteEditSheet(note: note),
      ),
    ),
  );

  testWidgets('alta: guardar despacha CreateRequested con tags parseadas', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('note_edit.content')),
      'Cliente nuevo, pidió catálogo',
    );
    await tester.enterText(
      find.byKey(const Key('note_edit.tags')),
      ' Ventas, catálogo ,, ventas ',
    );
    await tester.tap(find.byKey(const Key('note_edit.save')));
    await tester.pump();

    verify(
      () => bloc.add(
        const NotesCreateRequested(
          content: 'Cliente nuevo, pidió catálogo',
          // trim + lowercase + dedupe — espejo de la normalización S14.
          tags: <String>['ventas', 'catálogo'],
          color: '',
        ),
      ),
    ).called(1);
  });

  testWidgets('alta: guardar con contenido vacío no despacha nada', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('note_edit.save')));
    await tester.pump();

    verifyNever(() => bloc.add(any()));
  });

  testWidgets('edición: precarga contenido/tags y guarda UpdateRequested', (
    tester,
  ) async {
    await tester.pumpWidget(host(note: _existing));

    expect(find.text('Pidió factura'), findsOneWidget);
    expect(find.text('fiscal, urgente'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('note_edit.content')),
      'Pidió factura con RFC',
    );
    await tester.tap(find.byKey(const Key('note_edit.save')));
    await tester.pump();

    verify(
      () => bloc.add(
        const NotesUpdateRequested(
          id: 'n1',
          version: 2,
          content: 'Pidió factura con RFC',
          tags: <String>['fiscal', 'urgente'],
          color: '#3b82f6',
        ),
      ),
    ).called(1);
  });

  testWidgets('edición: borrar despacha DeleteRequested con la version', (
    tester,
  ) async {
    await tester.pumpWidget(host(note: _existing));

    await tester.tap(find.byKey(const Key('note_edit.delete')));
    await tester.pump();

    verify(
      () => bloc.add(const NotesDeleteRequested(id: 'n1', version: 2)),
    ).called(1);
  });

  testWidgets('alta: sin botón borrar', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('note_edit.delete')), findsNothing);
  });
}
