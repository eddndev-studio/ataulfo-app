import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/resources/domain/entities/resource_item.dart';
import 'package:ataulfo/features/resources/presentation/bloc/assistant_resources_cubit.dart';
import 'package:ataulfo/features/resources/presentation/pages/assistant_resources_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockResourcesCubit extends MockCubit<AssistantResourcesState>
    implements AssistantResourcesCubit {}

const _document = ResourceItem(
  id: 'r-doc',
  sourceId: 'd-1',
  kind: ResourceKind.knowledgeDocument,
  name: 'Manual operativo',
  active: true,
  sharedByDefault: true,
  indexable: true,
  sendable: false,
  version: 1,
);

const _catalog = ResourceItem(
  id: 'r-file',
  sourceId: 'f-1',
  kind: ResourceKind.file,
  name: 'Catálogo.pdf',
  active: true,
  sharedByDefault: false,
  indexable: false,
  sendable: true,
  version: 3,
);

void main() {
  late _MockResourcesCubit cubit;

  setUp(() {
    cubit = _MockResourcesCubit();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<AssistantResourcesCubit>.value(
      value: cubit,
      child: const AssistantResourcesPage(assistantName: 'Ventas'),
    ),
  );

  testWidgets('ALL muestra sólo recursos efectivos y oculta controles finos', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const AssistantResourcesLoaded(
        library: <ResourceItem>[_document, _catalog],
        effectiveIds: <String>{'r-doc'},
        scope: AssistantResourceScope.all,
        revision: 4,
      ),
    );

    await tester.pumpWidget(host());

    expect(find.text('Ventas'), findsOneWidget);
    expect(find.byKey(const Key('resources.item.r-doc')), findsOneWidget);
    expect(find.byKey(const Key('resources.item.r-file')), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Disponibles ahora'), findsOneWidget);
  });

  testWidgets('SELECTED revela catálogo y bloquea los heredados', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const AssistantResourcesLoaded(
        library: <ResourceItem>[_document, _catalog],
        effectiveIds: <String>{'r-doc'},
        scope: AssistantResourceScope.selected,
        revision: 4,
      ),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('resources.item.r-doc')), findsOneWidget);
    expect(find.byKey(const Key('resources.item.r-file')), findsOneWidget);
    final inherited = tester.widget<Switch>(
      find.byKey(const Key('resources.toggle.r-doc')),
    );
    final selectable = tester.widget<Switch>(
      find.byKey(const Key('resources.toggle.r-file')),
    );
    expect(inherited.value, isTrue);
    expect(inherited.onChanged, isNull);
    expect(selectable.value, isFalse);
    expect(selectable.onChanged, isNotNull);
    expect(find.textContaining('incluido por la organización'), findsOneWidget);
  });

  testWidgets('error ofrece reintento sin abandonar la superficie', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const AssistantResourcesFailed('Sin conexión.'));
    when(() => cubit.load()).thenAnswer((_) async {});

    await tester.pumpWidget(host());
    await tester.tap(find.text('Reintentar'));

    verify(() => cubit.load()).called(1);
    expect(find.text('Sin conexión.'), findsOneWidget);
  });
}
