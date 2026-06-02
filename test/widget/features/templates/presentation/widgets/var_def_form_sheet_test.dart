import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/var_defs_bloc.dart';
import 'package:ataulfo/features/templates/presentation/widgets/var_def_form_sheet.dart';
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
      expect(find.byKey(const Key('var_def_form.description')), findsOneWidget);
      expect(find.byKey(const Key('var_def_form.submit')), findsOneWidget);
      // El primitivo del DS, no Material directo.
      expect(find.byType(AppTextField), findsNWidgets(3));
      expect(find.byKey(const Key('var_def_form.submit')), findsOneWidget);
    });

    testWidgets('submit está deshabilitado cuando name está vacío', (
      tester,
    ) async {
      await tester.pumpWidget(host(existingNames: <String>{}));
      // El primitivo es AppButton.filled con onPressed=null cuando
      // name.trim().isEmpty.
      final submit = tester.widget<AppButton>(
        find.byKey(const Key('var_def_form.submit')),
      );
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
        final submit = tester.widget<AppButton>(
          find.byKey(const Key('var_def_form.submit')),
        );
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

      final submit = tester.widget<AppButton>(
        find.byKey(const Key('var_def_form.submit')),
      );
      expect(submit.loading, isTrue);
    });

    testWidgets('Loaded post-submit cierra el sheet automáticamente', (
      tester,
    ) async {
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
                        child: const VarDefFormSheet(existingNames: <String>{}),
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
    });

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

    testWidgets('Loaded sin haber sometido NO cierra (rebuilds incidentales)', (
      tester,
    ) async {
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
    });
  });

  group('VarDefFormSheet — padding inferior (teclado + system-nav)', () {
    // El sheet flota sobre el teclado virtual cuando el operador edita,
    // pero al cerrar el teclado en devices con gesture-nav (Android 15
    // típicamente reporta viewPadding.bottom ~30-40dp) el botón Guardar
    // queda parcialmente oculto detrás de la barra del sistema si el
    // padding solo cubre viewInsets.bottom (== 0 con teclado cerrado).
    // El padding inferior efectivo debe ser max(viewInsets, viewPadding)
    // para cubrir ambos escenarios sin doble-contar.
    Widget hostWithInsets({
      double viewPaddingBottom = 0,
      double viewInsetsBottom = 0,
    }) => MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: viewPaddingBottom),
            viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
          ),
          child: BlocProvider<VarDefsBloc>.value(
            value: bloc,
            child: const VarDefFormSheet(existingNames: <String>{}),
          ),
        ),
      ),
    );

    double sheetBottomPadding(WidgetTester tester) {
      // El sheet wrappea su Container interno en un Padding cuyo único
      // propósito es respetar el inset inferior. Lo identificamos como
      // el Padding ancestro inmediato del Container con padding.all.
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(AppButton),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.child is Container,
          ),
        ),
      );
      return (padding.padding as EdgeInsets).bottom;
    }

    testWidgets(
      'con teclado cerrado y system-nav presente, padding inferior cubre la system-nav',
      (tester) async {
        await tester.pumpWidget(hostWithInsets(viewPaddingBottom: 32));
        expect(
          sheetBottomPadding(tester),
          greaterThanOrEqualTo(32),
          reason:
              'Sin sumar viewPadding.bottom el botón Guardar queda detrás de '
              'la gesture-nav al cerrar el teclado.',
        );
      },
    );

    testWidgets('con teclado abierto, padding inferior cubre el teclado', (
      tester,
    ) async {
      // Subir el alto del viewport para que el sheet (3 fields + chip
      // picker + botón Guardar) quepa con viewInsets.bottom > 0. El
      // valor exacto del keyboard real (~280) es irrelevante para la
      // lógica — sólo se valida que viewInsets domina sobre viewPadding
      // cuando el teclado abre.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        hostWithInsets(viewInsetsBottom: 100, viewPaddingBottom: 32),
      );
      expect(sheetBottomPadding(tester), greaterThanOrEqualTo(100));
    });

    testWidgets(
      'sin teclado ni system-nav, padding inferior es 0 (no introduce gap espurio)',
      (tester) async {
        await tester.pumpWidget(hostWithInsets());
        expect(sheetBottomPadding(tester), 0);
      },
    );
  });

  group('VarDefFormSheet — modo edit', () {
    const editing = VariableDef(
      id: 'v1',
      name: 'nombre',
      defaultValue: 'cliente',
      description: 'Saludo personalizado',
    );

    Widget editHost({Set<String>? existingNames}) => MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: BlocProvider<VarDefsBloc>.value(
          value: bloc,
          child: VarDefFormSheet(
            existingNames: existingNames ?? <String>{'nombre', 'edad'},
            editing: editing,
          ),
        ),
      ),
    );

    testWidgets('pre-fillados con los valores del editing', (tester) async {
      await tester.pumpWidget(editHost());

      expect(find.text('nombre'), findsOneWidget);
      expect(find.text('cliente'), findsOneWidget);
      expect(find.text('Saludo personalizado'), findsOneWidget);
    });

    testWidgets('title del sheet refleja modo edit', (tester) async {
      await tester.pumpWidget(editHost());
      expect(find.text('Editar variable'), findsOneWidget);
      expect(find.text('Nueva variable'), findsNothing);
    });

    testWidgets(
      'dup hint NO se dispara cuando el name coincide con el editing original',
      (tester) async {
        // Sheet arranca con name pre-fillado = 'nombre'; aunque 'nombre'
        // está en existingNames, no es "duplicado" — es el mismo def.
        await tester.pumpWidget(editHost());

        expect(find.byKey(const Key('var_def_form.dup_hint')), findsNothing);
      },
    );

    testWidgets(
      'dup hint sí se dispara al cambiar a un name que ya existe en otro def',
      (tester) async {
        await tester.pumpWidget(editHost());

        await tester.enterText(
          find.byKey(const Key('var_def_form.name')),
          'edad',
        );
        await tester.pump();

        expect(find.byKey(const Key('var_def_form.dup_hint')), findsOneWidget);
      },
    );

    testWidgets(
      'submit dispatcha VarDefsUpdateRequested only-changed (campos sin cambio = null)',
      (tester) async {
        await tester.pumpWidget(editHost());

        // Sólo cambiar el name; los otros campos quedan iguales y
        // deben viajar como null (no-op del backend).
        await tester.enterText(
          find.byKey(const Key('var_def_form.name')),
          'nombre_x',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('var_def_form.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const VarDefsUpdateRequested(varDefId: 'v1', name: 'nombre_x'),
          ),
        ).called(1);
      },
    );

    testWidgets('submit con cambio en description: viaja sólo description', (
      tester,
    ) async {
      await tester.pumpWidget(editHost());

      await tester.enterText(
        find.byKey(const Key('var_def_form.description')),
        'Saludo nuevo',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('var_def_form.submit')));
      await tester.pump();

      verify(
        () => bloc.add(
          const VarDefsUpdateRequested(
            varDefId: 'v1',
            description: 'Saludo nuevo',
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'submit sin cambios es no-op (no dispatcha — UI evita request inútil)',
      (tester) async {
        await tester.pumpWidget(editHost());
        await tester.tap(find.byKey(const Key('var_def_form.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any(that: isA<VarDefsUpdateRequested>())));
      },
    );
  });
}
