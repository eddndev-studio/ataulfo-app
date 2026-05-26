import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_text_field.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/template_edit_bloc.dart';
import 'package:agentic/features/templates/presentation/pages/template_edit_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<TemplateEditEvent, TemplateEditState>
    implements TemplateEditBloc {}

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
    systemPrompt: 'Prompt actual.',
    contextMessages: 20,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplateEditLoadRequested());
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const TemplateEditLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<TemplateEditBloc>.value(
      value: bloc,
      child: const Scaffold(body: TemplateEditPage()),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateEditLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppTextField), findsNothing);
  });

  testWidgets('LoadFailed muestra error + Reintentar', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateEditLoadFailed(TemplatesNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('template_edit.load_error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara TemplateEditLoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateEditLoadFailed(TemplatesNetworkFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const TemplateEditLoadRequested())).called(1);
  });

  testWidgets(
    'Editing pre-fills nombre + systemPrompt con los valores del template',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateEditEditing(_tpl));

      await tester.pumpWidget(host());

      expect(find.text('Soporte'), findsOneWidget);
      expect(find.text('Prompt actual.'), findsOneWidget);
      // Submit habilitado por default cuando el form trae valores válidos.
      expect(find.widgetWithText(AppButton, 'Guardar'), findsOneWidget);
    },
  );

  testWidgets(
    'tap Guardar dispara TemplateEditSubmitted con los valores tipeados',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateEditEditing(_tpl));

      await tester.pumpWidget(host());
      await tester.enterText(
        find.byKey(const Key('template_edit.field.name')),
        'Soporte v2',
      );
      await tester.enterText(
        find.byKey(const Key('template_edit.field.system_prompt')),
        'Nuevo prompt.',
      );
      await tester.tap(find.byKey(const Key('template_edit.submit')));
      await tester.pump();

      verify(
        () => bloc.add(
          const TemplateEditSubmitted(
            name: 'Soporte v2',
            systemPrompt: 'Nuevo prompt.',
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('Submitting mantiene el form pero el botón está en loading', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateEditSubmitting(_tpl));

    await tester.pumpWidget(host());

    // El form sigue visible (preserva lo que el operador escribió).
    expect(find.text('Soporte'), findsOneWidget);
    // El botón está en loading (spinner inline). El primitivo bloquea
    // tap internamente; AppButton no expone su estado loading para el
    // test, así que verificamos la presencia del spinner inline en su
    // árbol.
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'SubmitFailed(Conflict) muestra copy específico de CAS + retry',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const TemplateEditSubmitFailed(
          failure: TemplatesConflictFailure(),
          template: _tpl,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_edit.error.conflict')),
        findsOneWidget,
      );
      // El form se mantiene editable después de Conflict — el operador
      // puede revisar, pero el copy le sugiere recargar primero.
      expect(find.text('Soporte'), findsOneWidget);
    },
  );

  testWidgets(
    'SubmitFailed(InvalidUpdate) muestra copy específico de validación',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const TemplateEditSubmitFailed(
          failure: TemplatesInvalidUpdateFailure(),
          template: _tpl,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_edit.error.invalid')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SubmitFailed(Network) muestra copy de red genérico',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const TemplateEditSubmitFailed(
          failure: TemplatesNetworkFailure(),
          template: _tpl,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('template_edit.error.network')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Succeeded apila el detalle por pushReplacement (form ya cumplió)',
    (tester) async {
      // Espejo del test de template_create_page: pushReplacement preserva
      // shell debajo, back físico vuelve al listado sin pasar por el form
      // que ya cumplió. context.go() aplastaría la pila.
      whenListen(
        bloc,
        Stream<TemplateEditState>.fromIterable(<TemplateEditState>[
          const TemplateEditSubmitting(_tpl),
          const TemplateEditSucceeded(_tpl),
        ]),
        initialState: const TemplateEditEditing(_tpl),
      );

      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/templates/t1/edit',
        routes: <RouteBase>[
          GoRoute(
            path: '/templates/t1/edit',
            builder: (_, _) => BlocProvider<TemplateEditBloc>.value(
              value: bloc,
              child: const Scaffold(body: TemplateEditPage()),
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
      await tester.pumpAndSettle();

      // Después de pushReplacement, el detalle NO debe poder pop (el form
      // fue reemplazado, no apilado). Si el form quedara apilado, back
      // volvería al form que ya guardó — UX rota.
      expect(
        canPopAtDestination,
        <bool>[false],
        reason:
            'pushReplacement reemplaza /templates/t1/edit con el detalle; '
            'el detalle no debe tener pila local que vuelva al form.',
      );
    },
  );
}
