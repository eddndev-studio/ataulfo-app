import 'dart:async';

import 'package:agentic/features/bots/presentation/pages/bot_template_picker_page.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

const _ai = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte ventas',
  version: 3,
  ai: _ai,
);
const _t2 = Template(
  id: 't2',
  orgId: 'o1',
  name: 'Ventas R&D / nivel 1',
  version: 1,
  ai: _ai,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplatesLoadRequested());
  });

  late _MockTemplatesBloc bloc;

  setUp(() {
    bloc = _MockTemplatesBloc();
    when(() => bloc.state).thenReturn(const TemplatesInitial());
  });

  Widget host() => MaterialApp(
    home: BlocProvider<TemplatesBloc>.value(
      value: bloc,
      child: const Scaffold(body: BotTemplatePickerPage()),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const TemplatesLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded con N templates renderiza un tile por cada uno', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[_t1, _t2], isRefreshing: false),
    );

    await tester.pumpWidget(host());

    expect(find.text('Soporte ventas'), findsOneWidget);
    expect(find.text('Ventas R&D / nivel 1'), findsOneWidget);
  });

  testWidgets(
    'Loaded vacío muestra empty state con copy que apunta a la tab Plantillas',
    (tester) async {
      // Sin plantillas el picker es dead-end: la única vía de salida es la
      // tab Plantillas (no acoplamos un atajo a /templates/new desde acá:
      // single-job del page + el operador debe aprender que las plantillas
      // viven en su propia tab).
      when(() => bloc.state).thenReturn(
        const TemplatesLoaded(items: <Template>[], isRefreshing: false),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('bot_template_picker.empty')),
        findsOneWidget,
      );
      expect(find.text('Soporte ventas'), findsNothing);
    },
  );

  testWidgets('Failed muestra mensaje y botón Reintentar', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplatesFailed(TemplatesNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_template_picker.error')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara TemplatesLoadRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplatesFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const TemplatesLoadRequested())).called(1);
  });

  testWidgets('isRefreshing: true mantiene la lista visible (no la oculta)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[_t1], isRefreshing: true),
    );

    await tester.pumpWidget(host());

    expect(find.text('Soporte ventas'), findsOneWidget);
  });

  testWidgets(
    'tap en un tile REEMPLAZA el picker por /templates/:id/bots/new?name=… '
    'preservando el shell debajo (canPop()==true)',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
      );

      // Stack inicial: shell → picker (via push). Tras tap del tile,
      // pushReplacement debe llevar a /templates/t1/bots/new?name=…
      // dejando el shell debajo (canPop()==true).
      //
      // Si el picker usara go() en lugar de pushReplacement el shell
      // se aplastaría y el back físico del form sacaría al operador
      // de la app — mismo bug reportado en el smoke de S03.
      final navigated = <String>[];
      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('SHELL')),
          ),
          GoRoute(
            path: '/bots/new',
            builder: (_, _) => BlocProvider<TemplatesBloc>.value(
              value: bloc,
              child: const Scaffold(body: BotTemplatePickerPage()),
            ),
          ),
          GoRoute(
            path: '/templates/:templateId/bots/new',
            builder: (_, state) {
              navigated.add(state.uri.toString());
              return Scaffold(
                body: Builder(
                  builder: (ctx) {
                    canPopAtDestination.add(Navigator.of(ctx).canPop());
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      unawaited(router.push<void>('/bots/new'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Soporte ventas'));
      await tester.pumpAndSettle();

      // `encodeQueryComponent` (form-urlencoded) codifica espacios como `+`,
      // no `%20`. El decoder (`state.uri.queryParameters`) lo revierte; lo
      // que NO podemos hacer es interpolar el nombre crudo, porque el `?`,
      // `&`, `=` o `#` dentro del nombre romperían el query. Consistente
      // con el otro entry point (template_detail_page).
      expect(navigated, <String>['/templates/t1/bots/new?name=Soporte+ventas']);
      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'pushReplacement reemplaza el picker pero conserva el shell '
            'como base de la pila; el back físico del form debe volver al '
            'shell, no salir de la app',
      );
    },
  );

  testWidgets(
    'nombres con caracteres reservados de URL viajan percent-encoded en el '
    'query',
    (tester) async {
      // Sin encoding `&` rompería el query (Uri lo trataría como separador
      // de pares clave=valor); el form al leer queryParameters['name']
      // recibiría sólo "Ventas R" en lugar del nombre completo.
      when(() => bloc.state).thenReturn(
        const TemplatesLoaded(items: <Template>[_t2], isRefreshing: false),
      );

      String? receivedName;
      final router = GoRouter(
        initialLocation: '/bots/new',
        routes: <RouteBase>[
          GoRoute(
            path: '/bots/new',
            builder: (_, _) => BlocProvider<TemplatesBloc>.value(
              value: bloc,
              child: const Scaffold(body: BotTemplatePickerPage()),
            ),
          ),
          GoRoute(
            path: '/templates/:templateId/bots/new',
            builder: (_, state) {
              receivedName = state.uri.queryParameters['name'];
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Ventas R&D / nivel 1'));
      await tester.pumpAndSettle();

      // El form lo decodifica al leer queryParameters; lo crítico es que
      // llegue sano (no truncado por el `&` ni roto por la `/`).
      expect(receivedName, 'Ventas R&D / nivel 1');
    },
  );
}
