import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_create_bloc.dart';
import 'package:ataulfo/features/flows/presentation/pages/flow_create_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowCreateBloc>.value(
      value: bloc,
      child: const Scaffold(body: FlowCreatePage()),
    ),
  );

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(const Key('flow_create.submit')));

  testWidgets('Initial: input + botón "Crear" deshabilitado', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byKey(const Key('flow_create.field.name')), findsOneWidget);
    final btn = submitButton(tester);
    expect(btn.onPressed, isNull);
    expect(btn.loading, false);
  });

  testWidgets('al escribir texto el botón se habilita', (tester) async {
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

    final btn = submitButton(tester);
    expect(btn.loading, true);

    final field = tester.widget<AppTextField>(
      find.byKey(const Key('flow_create.field.name')),
    );
    expect(field.enabled, false);
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

  testWidgets('Failed(Server) muestra el copy genérico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowCreateFailed(FlowsServerFailure()));
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_create.error.generic')), findsOneWidget);
  });

  testWidgets(
    'Succeeded dispara pushReplacement a /flows/:id (no go ni push)',
    (tester) async {
      String? destinationUri;
      bool? canPopAtDestination;
      whenListen(
        bloc,
        Stream<FlowCreateState>.fromIterable(<FlowCreateState>[
          const FlowCreateInitial(),
          const FlowCreateSubmitting(),
          const FlowCreateSucceeded(_flow),
        ]),
        initialState: const FlowCreateInitial(),
      );

      final router = GoRouter(
        initialLocation: '/templates/t1/flows/new',
        routes: <RouteBase>[
          GoRoute(
            path: '/templates/:templateId/flows/new',
            builder: (_, _) => BlocProvider<FlowCreateBloc>.value(
              value: bloc,
              child: const Scaffold(body: FlowCreatePage()),
            ),
          ),
          GoRoute(
            path: '/flows/:id',
            builder: (BuildContext ctx, GoRouterState st) {
              destinationUri = st.uri.toString();
              canPopAtDestination = ctx.canPop();
              return const Scaffold(body: Text('Detalle del flujo'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detalle del flujo'), findsOneWidget);
      expect(destinationUri, '/flows/f-new');
      expect(
        canPopAtDestination,
        false,
        reason:
            'pushReplacement debe dejar el form fuera de la pila '
            'para que el back físico vuelva al template, no al form',
      );
    },
  );
}
