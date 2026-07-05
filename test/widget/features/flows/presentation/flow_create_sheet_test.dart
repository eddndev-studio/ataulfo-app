import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_create_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/flow_create_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<FlowCreateEvent, FlowCreateState>
    implements FlowCreateBloc {}

const _flow = fdom.Flow(
  id: 'f-new',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowCreateSubmitted(name: ''));
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const FlowCreateInitial());
  });

  // La hoja es content-only (la abre showModalBottomSheet en prod). En
  // aislamiento la montamos dentro de un Scaffold con el bloc inyectado.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowCreateBloc>.value(
      value: bloc,
      child: const Scaffold(body: FlowCreateSheet()),
    ),
  );

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(const Key('flow_create.submit')));

  testWidgets('título "Nuevo flujo", campo y submit deshabilitado', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.text('Nuevo flujo'), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byKey(const Key('flow_create.field.name')), findsOneWidget);
    final btn = submitButton(tester);
    expect(btn.onPressed, isNull, reason: 'name vacío deshabilita el submit');
    expect(btn.loading, false);
  });

  testWidgets('al escribir texto, el botón se habilita', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('flow_create.field.name')),
      'Bienvenida',
    );
    await tester.pump();

    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('tap "Crear" dispara FlowCreateSubmitted con name trim', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('flow_create.field.name')),
      '  Bienvenida  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('flow_create.submit')));
    await tester.pump();

    verify(
      () => bloc.add(const FlowCreateSubmitted(name: 'Bienvenida')),
    ).called(1);
  });

  testWidgets('Submitting: botón en loading + input deshabilitado', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const FlowCreateSubmitting());

    await tester.pumpWidget(host());

    expect(submitButton(tester).loading, true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final field = tester.widget<AppTextField>(
      find.byKey(const Key('flow_create.field.name')),
    );
    expect(field.enabled, false);
  });

  testWidgets('el copy de error sale del textTheme, no de un estilo crudo', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowCreateFailed(FlowsInvalidCreateFailure()));

    await tester.pumpWidget(host());

    final finder = find.byKey(const Key('flow_create.error.invalid_create'));
    final ctx = tester.element(finder);
    expect(
      tester.widget<Text>(finder).style,
      Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
    );
  });

  testWidgets('Failed(InvalidCreate) muestra el copy específico', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowCreateFailed(FlowsInvalidCreateFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('flow_create.error.invalid_create')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('flow_create.error.generic')), findsNothing);
  });

  testWidgets('Failed(Forbidden) muestra el copy de RBAC', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowCreateFailed(FlowsForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('flow_create.error.forbidden')),
      findsOneWidget,
    );
  });

  testWidgets('Failed(Network) muestra el copy de red', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowCreateFailed(FlowsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_create.error.network')), findsOneWidget);
  });

  testWidgets('Failed(Server) colapsa al copy genérico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowCreateFailed(FlowsServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_create.error.generic')), findsOneWidget);
  });

  testWidgets('Succeeded cierra la hoja devolviendo el Flow creado', (
    tester,
  ) async {
    // Al éxito la hoja hace Navigator.pop(flow); quien la abrió decide la
    // navegación (sustituye al pushReplacement de la pantalla dedicada).
    final controller = StreamController<FlowCreateState>();
    addTearDown(controller.close);
    whenListen(
      bloc,
      controller.stream,
      initialState: const FlowCreateInitial(),
    );

    fdom.Flow? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  returned = await Navigator.of(ctx).push<fdom.Flow>(
                    MaterialPageRoute<fdom.Flow>(
                      // En prod showModalBottomSheet aporta el Material;
                      // aquí lo simula el Scaffold de la ruta empujada.
                      builder: (_) => BlocProvider<FlowCreateBloc>.value(
                        value: bloc,
                        child: const Scaffold(body: FlowCreateSheet()),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo flujo'), findsOneWidget);

    controller.add(const FlowCreateSucceeded(_flow));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo flujo'), findsNothing, reason: 'cerró');
    expect(returned, _flow);
  });
}
