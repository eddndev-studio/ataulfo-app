import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/trainer/domain/entities/workspace_doc.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/trainer/presentation/bloc/workspace_bloc.dart';
import 'package:ataulfo/features/trainer/presentation/widgets/workspace_doc_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWorkspaceBloc extends MockBloc<WorkspaceEvent, WorkspaceState>
    implements WorkspaceBloc {}

class _FakeWorkspaceRepo implements WorkspaceRepository {
  _FakeWorkspaceRepo({this.doc});

  final WorkspaceDoc? doc;

  @override
  Future<WorkspaceDoc> getDoc({
    required String templateId,
    required String name,
  }) async => doc!;

  @override
  Future<List<WorkspaceDoc>> listDocs({required String templateId}) async =>
      const <WorkspaceDoc>[];

  @override
  Future<WorkspaceDoc> createDoc({
    required String templateId,
    required String name,
    required String content,
  }) async => doc!;

  @override
  Future<WorkspaceDoc> updateDoc({
    required String templateId,
    required String name,
    required String content,
    required int version,
  }) async => doc!;

  @override
  Future<void> deleteDoc({
    required String templateId,
    required String name,
    required int version,
  }) async {}
}

final _doc = WorkspaceDoc(
  name: 'menu-precios',
  content: 'Tacos: 20 MXN',
  sizeBytes: 13,
  updatedByKind: 'operator',
  version: 3,
  createdAt: DateTime.utc(2026, 6, 1),
  updatedAt: DateTime.utc(2026, 6, 2),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const WorkspaceLoadRequested());
  });

  late _MockWorkspaceBloc bloc;

  setUp(() {
    bloc = _MockWorkspaceBloc();
    when(() => bloc.state).thenReturn(const WorkspaceLoading());
    when(() => bloc.templateId).thenReturn('tpl1');
  });

  Widget host({WorkspaceDoc? doc, required Widget child}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<WorkspaceBloc>.value(
        value: bloc,
        child: RepositoryProvider<WorkspaceRepository>.value(
          value: _FakeWorkspaceRepo(doc: doc),
          child: child,
        ),
      ),
    ),
  );

  group('WorkspaceDocSheet — anatomía canónica de form-sheet', () {
    testWidgets('creación: H1 titleLarge + fields del kit + CTA fullWidth', (
      tester,
    ) async {
      await tester.pumpWidget(host(child: const WorkspaceDocSheet()));
      await tester.pumpAndSettle();

      final theme = AppDesignTheme.dark();
      final title = tester.widget<Text>(find.text('Nuevo documento'));
      expect(title.style?.fontSize, theme.textTheme.titleLarge?.fontSize);

      // Los campos son del kit, no TextField crudo con OutlineInputBorder.
      expect(find.byKey(const Key('workspace_doc.name')), findsOneWidget);
      expect(find.byKey(const Key('workspace_doc.content')), findsOneWidget);
      expect(find.byType(AppTextField), findsNWidgets(2));

      final save = tester.widget<AppButton>(
        find.byKey(const Key('workspace_doc.save')),
      );
      expect(save.fullWidth, isTrue);

      // Form-sheet canónico: scrollea (teclado) y sin botón de borrar al crear.
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byKey(const Key('workspace_doc.delete')), findsNothing);
    });

    testWidgets('el modal se abre sobre surface1 (fondo canónico)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => WorkspaceDocSheet.openCreate(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, AppTokens.surface1);
    });
  });

  group('WorkspaceDocSheet — comportamiento', () {
    testWidgets('crear despacha WorkspaceDocCreated con nombre recortado', (
      tester,
    ) async {
      await tester.pumpWidget(host(child: const WorkspaceDocSheet()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('workspace_doc.name')),
        '  menu-precios ',
      );
      await tester.enterText(
        find.byKey(const Key('workspace_doc.content')),
        'Tacos: 20 MXN',
      );
      await tester.tap(find.byKey(const Key('workspace_doc.save')));
      await tester.pump();

      // Los eventos del WorkspaceBloc no implementan ==: se matchea por shape.
      verify(
        () => bloc.add(
          any(
            that: isA<WorkspaceDocCreated>()
                .having((e) => e.name, 'name', 'menu-precios')
                .having((e) => e.content, 'content', 'Tacos: 20 MXN'),
          ),
        ),
      ).called(1);
    });

    testWidgets('doc existente: carga el contenido, titula con el nombre y '
        'guardar despacha WorkspaceDocUpdated con la versión', (tester) async {
      await tester.pumpWidget(
        host(
          doc: _doc,
          child: const WorkspaceDocSheet(name: 'menu-precios'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('menu-precios'), findsOneWidget);
      expect(find.text('Tacos: 20 MXN'), findsOneWidget);
      // El nombre es la identidad del doc: no se reedita.
      expect(find.byKey(const Key('workspace_doc.name')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('workspace_doc.content')),
        'Tacos: 25 MXN',
      );
      await tester.tap(find.byKey(const Key('workspace_doc.save')));
      await tester.pump();

      verify(
        () => bloc.add(
          any(
            that: isA<WorkspaceDocUpdated>()
                .having((e) => e.name, 'name', 'menu-precios')
                .having((e) => e.content, 'content', 'Tacos: 25 MXN')
                .having((e) => e.version, 'version', 3),
          ),
        ),
      ).called(1);
    });

    testWidgets('borrar pide confirmación y despacha WorkspaceDocDeleted', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          doc: _doc,
          child: const WorkspaceDocSheet(name: 'menu-precios'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('workspace_doc.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace_doc.delete_confirm')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          any(
            that: isA<WorkspaceDocDeleted>()
                .having((e) => e.name, 'name', 'menu-precios')
                .having((e) => e.version, 'version', 3),
          ),
        ),
      ).called(1);
    });
  });
}
