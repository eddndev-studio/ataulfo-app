import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/template_create_bloc.dart';
import 'package:agentic/features/templates/presentation/pages/template_create_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<TemplateCreateEvent, TemplateCreateState>
    implements TemplateCreateBloc {}

const _tpl = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 1,
  ai: AIConfig(
    enabled: false,
    provider: AIProvider.gemini,
    model: 'gemini-3.1-pro-preview',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.low,
    systemPrompt: '',
    contextMessages: 20,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplateCreateSubmitted(name: ''));
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const TemplateCreateInitial());
  });

  Widget host() => MaterialApp(
    home: BlocProvider<TemplateCreateBloc>.value(
      value: bloc,
      // Página content-only: el shell de la ruta aporta Scaffold/AppBar.
      // En aislamiento envolvemos en Scaffold para tener Material upstream.
      child: const Scaffold(body: TemplateCreatePage()),
    ),
  );

  testWidgets('Initial muestra TextField y botón "Crear" deshabilitado', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('template_create.field.name')), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('template_create.submit')),
    );
    expect(btn.onPressed, isNull, reason: 'name vacío deshabilita el submit');
  });

  testWidgets('al escribir texto, el botón se habilita', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('template_create.field.name')),
      'Soporte',
    );
    await tester.pump();

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('template_create.submit')),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('tap "Crear" dispara TemplateCreateSubmitted con name trim', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('template_create.field.name')),
      '  Soporte  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('template_create.submit')));
    await tester.pump();

    verify(
      () => bloc.add(const TemplateCreateSubmitted(name: 'Soporte')),
    ).called(1);
  });

  testWidgets('Submitting muestra spinner y deshabilita el botón', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateCreateSubmitting());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('template_create.submit')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('Failed(InvalidName) muestra error con copy específico', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateCreateFailed(TemplatesInvalidNameFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_create.error.invalid_name')),
      findsOneWidget,
    );
    // No debe colapsar al genérico ni al de forbidden/network.
    expect(
      find.byKey(const Key('template_create.error.generic')),
      findsNothing,
    );
  });

  testWidgets('Failed(Forbidden) muestra error de permisos', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateCreateFailed(TemplatesForbiddenFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_create.error.forbidden')),
      findsOneWidget,
    );
  });

  testWidgets('Failed(Network) muestra error de red', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateCreateFailed(TemplatesNetworkFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_create.error.network')),
      findsOneWidget,
    );
  });

  testWidgets('Failed(Server) colapsa al copy genérico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateCreateFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_create.error.generic')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Succeeded reemplaza /templates/new con /templates/{id} sobre la pila '
    'del shell (back vuelve al shell, no al formulario)',
    (tester) async {
      // Reproducción del bug del smoke device: si la página usa go() en
      // Succeeded, la pila se aplasta y el back del sistema saca al
      // usuario de la app. pushReplacement() reemplaza /templates/new
      // con /templates/{id} dejando el shell debajo (canPop = true).
      whenListen(
        bloc,
        Stream<TemplateCreateState>.fromIterable(const <TemplateCreateState>[
          TemplateCreateSucceeded(_tpl),
        ]),
        initialState: const TemplateCreateInitial(),
      );

      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('SHELL')),
          ),
          GoRoute(
            path: '/templates/new',
            builder: (_, _) => BlocProvider<TemplateCreateBloc>.value(
              value: bloc,
              child: const Scaffold(body: TemplateCreatePage()),
            ),
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (ctx) {
                  canPopAtDestination.add(Navigator.of(ctx).canPop());
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/templates/new');
      await tester.pumpAndSettle();

      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'tras Succeeded, el detalle debe quedar sobre la pila del shell; '
            'pushReplacement reemplaza /templates/new (no se vuelve al form) '
            'pero preserva el shell debajo (back vuelve al shell)',
      );
    },
  );

  testWidgets('Succeeded navega a /templates/{id} (registra la url)', (
    tester,
  ) async {
    // El estado terminal arranca como Succeeded para que el BlocListener
    // dispare la navegación en el primer pump. La página es content-only
    // y delega el go() al GoRouter del entorno.
    when(() => bloc.state).thenReturn(const TemplateCreateSucceeded(_tpl));
    whenListen(
      bloc,
      Stream<TemplateCreateState>.fromIterable(const <TemplateCreateState>[
        TemplateCreateSucceeded(_tpl),
      ]),
      initialState: const TemplateCreateInitial(),
    );

    final navigated = <String>[];
    final router = GoRouter(
      initialLocation: '/templates/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/templates/new',
          builder: (_, _) => BlocProvider<TemplateCreateBloc>.value(
            value: bloc,
            child: const Scaffold(body: TemplateCreatePage()),
          ),
        ),
        GoRoute(
          path: '/templates/:id',
          builder: (_, state) {
            navigated.add('/templates/${state.pathParameters['id']}');
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(navigated, <String>['/templates/t1']);
  });
}
