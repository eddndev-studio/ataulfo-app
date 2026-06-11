import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/var_defs_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_variables_page.dart';
import 'package:ataulfo/features/templates/presentation/widgets/var_def_form_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVarDefsBloc extends MockBloc<VarDefsEvent, VarDefsState>
    implements VarDefsBloc {}

VariableDef _def({
  required String id,
  required String name,
  String defaultValue = '',
  String description = '',
}) => VariableDef(
  id: id,
  name: name,
  defaultValue: defaultValue,
  description: description,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const VarDefsLoadRequested());
  });

  late _MockVarDefsBloc varDefsBloc;

  setUp(() {
    varDefsBloc = _MockVarDefsBloc();
    when(
      () => varDefsBloc.state,
    ).thenReturn(const VarDefsLoaded(<VariableDef>[], 1));
  });

  // La página posee su Scaffold (AppBar + FAB); el host solo provee el bloc.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<VarDefsBloc>.value(
      value: varDefsBloc,
      child: const TemplateVariablesPage(),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => varDefsBloc.state).thenReturn(const VarDefsLoading());

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('var_defs.loading')), findsOneWidget);
  });

  testWidgets('Loaded([]) muestra empty state y oculta el buscador', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('var_defs.empty')), findsOneWidget);
    expect(find.byKey(const Key('template_variables.search')), findsNothing);
  });

  testWidgets('Loaded con defs muestra una fila por variable', (tester) async {
    when(() => varDefsBloc.state).thenReturn(
      VarDefsLoaded(<VariableDef>[
        _def(
          id: 'v1',
          name: 'nombre',
          defaultValue: 'cliente',
          description: 'Saludo personalizado',
        ),
        _def(id: 'v2', name: 'edad'),
      ], 2),
    );

    await tester.pumpWidget(host());

    expect(find.text('{{nombre}}'), findsOneWidget);
    expect(find.text('cliente'), findsOneWidget);
    expect(find.text('Saludo personalizado'), findsOneWidget);
    expect(find.text('{{edad}}'), findsOneWidget);
  });

  group('buscador', () {
    setUp(() {
      when(() => varDefsBloc.state).thenReturn(
        VarDefsLoaded(<VariableDef>[
          _def(id: 'v1', name: 'nombre'),
          _def(id: 'v2', name: 'edad'),
          _def(id: 'v3', name: 'nombre_negocio'),
        ], 2),
      );
    });

    testWidgets('filtra por nombre (case-insensitive)', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('template_variables.search')),
        'NOMBRE',
      );
      await tester.pump();

      expect(find.byKey(const Key('var_defs.row.v1')), findsOneWidget);
      expect(find.byKey(const Key('var_defs.row.v3')), findsOneWidget);
      expect(find.byKey(const Key('var_defs.row.v2')), findsNothing);
    });

    testWidgets('sin coincidencias muestra mensaje de no-resultados', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('template_variables.search')),
        'zzz',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('template_variables.no_results')),
        findsOneWidget,
      );
    });
  });

  testWidgets('VarDefsFailed muestra error + Reintentar dispatcha load', (
    tester,
  ) async {
    when(
      () => varDefsBloc.state,
    ).thenReturn(const VarDefsFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('var_defs.failed')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => varDefsBloc.add(const VarDefsLoadRequested())).called(1);
  });

  testWidgets('la página posee AppBar "Variables" y FAB [+]; muere el botón '
      'inline de texto', (tester) async {
    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppBar, 'Variables'), findsOneWidget);
    expect(find.byKey(const Key('template_variables.fab')), findsOneWidget);
    expect(find.byKey(const Key('var_defs.add_button')), findsNothing);
    expect(find.text('Agregar variable'), findsNothing);
  });

  testWidgets('Mutating oculta el FAB (no doble dispatch)', (tester) async {
    when(
      () => varDefsBloc.state,
    ).thenReturn(const VarDefsMutating(<VariableDef>[], 1));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('template_variables.fab')), findsNothing);
  });

  testWidgets('tap del FAB abre el VarDefFormSheet', (tester) async {
    when(() => varDefsBloc.state).thenReturn(
      VarDefsLoaded(<VariableDef>[_def(id: 'v1', name: 'nombre')], 2),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('template_variables.fab')));
    await tester.pumpAndSettle();

    expect(find.byType(VarDefFormSheet), findsOneWidget);
  });

  testWidgets('tap row abre el sheet en modo edit', (tester) async {
    when(() => varDefsBloc.state).thenReturn(
      VarDefsLoaded(<VariableDef>[
        _def(id: 'v1', name: 'nombre', description: 'Saludo personalizado'),
      ], 2),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.text('{{nombre}}'));
    await tester.pumpAndSettle();

    expect(find.byType(VarDefFormSheet), findsOneWidget);
    expect(find.text('Editar variable'), findsOneWidget);
  });

  testWidgets('tap trash abre confirm; Eliminar dispatcha DeleteRequested', (
    tester,
  ) async {
    when(() => varDefsBloc.state).thenReturn(
      VarDefsLoaded(<VariableDef>[_def(id: 'v1', name: 'nombre')], 2),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('var_defs.row.v1.delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('var_defs.delete_confirm')), findsOneWidget);
    verifyNever(() => varDefsBloc.add(any()));

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    verify(
      () => varDefsBloc.add(const VarDefsDeleteRequested(varDefId: 'v1')),
    ).called(1);
  });

  testWidgets('MutationFailed muestra SnackBar con copy de recarga', (
    tester,
  ) async {
    final controller = StreamController<VarDefsState>.broadcast();
    addTearDown(controller.close);
    whenListen<VarDefsState>(
      varDefsBloc,
      controller.stream,
      initialState: const VarDefsLoaded(<VariableDef>[], 1),
    );

    await tester.pumpWidget(host());
    controller.add(
      const VarDefsMutationFailed(
        <VariableDef>[],
        1,
        TemplatesConflictFailure(),
      ),
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.textContaining('plantilla cambió', findRichText: true),
      findsOneWidget,
    );
  });
}
