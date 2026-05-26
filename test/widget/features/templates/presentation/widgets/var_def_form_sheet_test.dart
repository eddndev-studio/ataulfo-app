import 'dart:async';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_text_field.dart';
import 'package:agentic/features/templates/domain/entities/variable_def.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/var_defs_bloc.dart';
import 'package:agentic/features/templates/presentation/widgets/var_def_form_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<VarDefsEvent, VarDefsState>
    implements VarDefsBloc {}

const _defs = <VariableDef>[
  VariableDef(
    id: 'v1',
    name: 'nombre',
    type: VarType.text,
    defaultValue: 'cliente',
    description: '',
  ),
];

void main() {
  setUpAll(() {
    // mocktail necesita un fallback de VarDefsEvent para `verify(() => bloc.add(any()))`
    // y para `whenListen` con default state. Como VarDefsEvent es sealed, usamos un
    // miembro concreto del set.
    registerFallbackValue(const VarDefsLoadRequested());
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const VarDefsLoaded(_defs, 2));
  });

  Widget host({Set<String>? existingNames}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: BlocProvider<VarDefsBloc>.value(
        value: bloc,
        child: VarDefFormSheet(
          existingNames: existingNames ?? <String>{'nombre'},
        ),
      ),
    ),
  );

  group('VarDefFormSheet — estructura', () {
    testWidgets('renderiza 3 fields y botón Guardar con keys contractuales', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(find.byKey(const Key('var_def_form.name')), findsOneWidget);
      expect(find.byKey(const Key('var_def_form.default')), findsOneWidget);
      expect(
        find.byKey(const Key('var_def_form.description')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('var_def_form.submit')), findsOneWidget);
      // El primitivo del DS, no Material directo.
      expect(find.byType(AppTextField), findsNWidgets(3));
      expect(
        find.byKey(const Key('var_def_form.submit')),
        findsOneWidget,
      );
    });

    testWidgets('submit está deshabilitado cuando name está vacío', (
      tester,
    ) async {
      await tester.pumpWidget(host(existingNames: <String>{}));
      // El primitivo es AppButton.filled con onPressed=null cuando
      // name.trim().isEmpty.
      final submit = tester
          .widget<AppButton>(find.byKey(const Key('var_def_form.submit')));
      expect(submit.onPressed, isNull);
    });
  });

  group('VarDefFormSheet — submit', () {
    testWidgets(
      'tap submit con name no vacío dispatcha VarDefsAddRequested con los valores',
      (tester) async {
        await tester.pumpWidget(host(existingNames: <String>{}));

        await tester.enterText(
          find.byKey(const Key('var_def_form.name')),
          'saldo',
        );
        await tester.enterText(
          find.byKey(const Key('var_def_form.default')),
          'x',
        );
        await tester.enterText(
          find.byKey(const Key('var_def_form.description')),
          'saldo del cliente',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('var_def_form.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const VarDefsAddRequested(
              name: 'saldo',
              type: VarType.text,
              defaultValue: 'x',
              description: 'saldo del cliente',
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('name se trimea antes de dispatchar (no padding raro)', (
      tester,
    ) async {
      await tester.pumpWidget(host(existingNames: <String>{}));

      await tester.enterText(
        find.byKey(const Key('var_def_form.name')),
        '  saldo  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('var_def_form.submit')));
      await tester.pump();

      verify(
        () => bloc.add(
          const VarDefsAddRequested(
            name: 'saldo',
            type: VarType.text,
            defaultValue: '',
            description: '',
          ),
        ),
      ).called(1);
    });
  });

  group('VarDefFormSheet — pre-flight nombre duplicado', () {
    testWidgets(
      'mostrar hint inline cuando el name existe en defs (no bloquea submit)',
      (tester) async {
        await tester.pumpWidget(host(existingNames: <String>{'nombre'}));

        await tester.enterText(
          find.byKey(const Key('var_def_form.name')),
          'nombre',
        );
        await tester.pump();

        expect(
          find.byKey(const Key('var_def_form.dup_hint')),
          findsOneWidget,
          reason: 'pre-flight visible cuando colisiona con la lista actual',
        );
        // No deshabilita: el operador puede insistir y el server 409
        // es la fuente de verdad (race con otro operador, etc.).
        final submit = tester
            .widget<AppButton>(find.byKey(const Key('var_def_form.submit')));
        expect(submit.onPressed, isNotNull);
      },
    );

    testWidgets('hint desaparece cuando el name cambia a uno único', (
      tester,
    ) async {
      await tester.pumpWidget(host(existingNames: <String>{'nombre'}));

      await tester.enterText(
        find.byKey(const Key('var_def_form.name')),
        'nombre',
      );
      await tester.pump();
      expect(find.byKey(const Key('var_def_form.dup_hint')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('var_def_form.name')),
        'saldo',
      );
      await tester.pump();

      expect(find.byKey(const Key('var_def_form.dup_hint')), findsNothing);
    });
  });

  group('VarDefFormSheet — reacciones al state del bloc', () {
    testWidgets('Mutating: submit con loading=true (no permite re-tap)', (
      tester,
    ) async {
      // Stream el estado: arranca Loaded, transiciona a Mutating tras
      // el primer tap. whenListen del bloc_test cubre esto.
      when(() => bloc.state).thenReturn(const VarDefsMutating(_defs, 2));

      await tester.pumpWidget(host(existingNames: <String>{}));

      final submit = tester
          .widget<AppButton>(find.byKey(const Key('var_def_form.submit')));
      expect(submit.loading, isTrue);
    });

    testWidgets(
      'Loaded post-submit cierra el sheet automáticamente',
      (tester) async {
        // StreamController permite emitir estados DESPUÉS del tap submit
        // (Stream.fromIterable los entrega de golpe al subscribirse).
        final controller = StreamController<VarDefsState>.broadcast();
        addTearDown(controller.close);
        whenListen<VarDefsState>(
          bloc,
          controller.stream,
          initialState: const VarDefsLoaded(_defs, 2),
        );

        var didPop = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: Scaffold(
              // Resizable: el sheet expandido con teclado oculto cabe
              // en cualquier altura sin overflow.
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) => AppButton.text(
                    label: 'Open',
                    onPressed: () async {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => BlocProvider<VarDefsBloc>.value(
                          value: bloc,
                          child:
                              const VarDefFormSheet(existingNames: <String>{}),
                        ),
                      );
                      didPop = true;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap submit (didSubmit=true). Recién después emitimos los
        // estados del flow.
        await tester.enterText(
          find.byKey(const Key('var_def_form.name')),
          'saldo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('var_def_form.submit')));
        await tester.pump();

        controller.add(const VarDefsMutating(_defs, 2));
        await tester.pump();
        controller.add(const VarDefsLoading());
        await tester.pump();
        controller.add(const VarDefsLoaded(_defs, 3));
        await tester.pumpAndSettle();

        expect(didPop, isTrue, reason: 'el sheet debe cerrarse en Loaded');
        expect(find.byType(VarDefFormSheet), findsNothing);
      },
    );

    testWidgets(
      'MutationFailed NO cierra el sheet (operador corrige y reintenta)',
      (tester) async {
        final controller = StreamController<VarDefsState>.broadcast();
        addTearDown(controller.close);
        whenListen<VarDefsState>(
          bloc,
          controller.stream,
          initialState: const VarDefsLoaded(_defs, 2),
        );

        await tester.pumpWidget(host(existingNames: <String>{}));

        await tester.enterText(
          find.byKey(const Key('var_def_form.name')),
          'saldo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('var_def_form.submit')));
        await tester.pump();

        controller.add(const VarDefsMutating(_defs, 2));
        await tester.pump();
        controller.add(
          const VarDefsMutationFailed(_defs, 2, TemplatesConflictFailure()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VarDefFormSheet), findsOneWidget);
      },
    );

    testWidgets(
      'Loaded sin haber sometido NO cierra (rebuilds incidentales)',
      (tester) async {
        // Un rebuild del bloc a Loaded sin que el sheet haya disparado
        // submit (p.ej. un refetch externo) no debe cerrar — el flag
        // didSubmit lo evita.
        final controller = StreamController<VarDefsState>.broadcast();
        addTearDown(controller.close);
        whenListen<VarDefsState>(
          bloc,
          controller.stream,
          initialState: const VarDefsLoaded(_defs, 2),
        );

        await tester.pumpWidget(host(existingNames: <String>{}));
        controller.add(const VarDefsLoaded(_defs, 3));
        await tester.pumpAndSettle();

        expect(find.byType(VarDefFormSheet), findsOneWidget);
      },
    );
  });
}
