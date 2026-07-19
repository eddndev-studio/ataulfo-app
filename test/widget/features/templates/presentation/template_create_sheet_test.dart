import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/template_create_bloc.dart';
import 'package:ataulfo/features/templates/presentation/widgets/template_create_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // La hoja es content-only (la abre showModalBottomSheet en prod). En
  // aislamiento la montamos dentro de un Scaffold con el bloc inyectado.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<TemplateCreateBloc>.value(
      value: bloc,
      child: const Scaffold(body: TemplateCreateSheet()),
    ),
  );

  AppButton submitButton(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(const Key('template_create.submit')));

  testWidgets('título "Nuevo Asistente", campo y submit deshabilitado', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.text('Nuevo Asistente'), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byKey(const Key('template_create.field.name')), findsOneWidget);
    final btn = submitButton(tester);
    expect(btn.onPressed, isNull, reason: 'name vacío deshabilita el submit');
    expect(btn.loading, false);
  });

  testWidgets('al escribir texto, el botón se habilita', (tester) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const Key('template_create.field.name')),
      'Soporte',
    );
    await tester.pump();

    expect(submitButton(tester).onPressed, isNotNull);
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

  testWidgets('Submitting pone el AppButton en loading=true', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateCreateSubmitting());

    await tester.pumpWidget(host());

    expect(submitButton(tester).loading, true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('el copy de error sale del textTheme, no de un estilo crudo', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateCreateFailed(TemplatesInvalidNameFailure()));

    await tester.pumpWidget(host());

    final finder = find.byKey(const Key('template_create.error.invalid_name'));
    final ctx = tester.element(finder);
    expect(
      tester.widget<Text>(finder).style,
      Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
    );
  });

  testWidgets('Failed(InvalidName) muestra error específico', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateCreateFailed(TemplatesInvalidNameFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_create.error.invalid_name')),
      findsOneWidget,
    );
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

  testWidgets('Succeeded cierra la hoja devolviendo la Template creada', (
    tester,
  ) async {
    // Contrato nuevo (sustituye al pushReplacement de la pantalla): al éxito
    // la hoja hace Navigator.pop(template); quien la abrió navega con eso.
    final controller = StreamController<TemplateCreateState>();
    addTearDown(controller.close);
    whenListen(
      bloc,
      controller.stream,
      initialState: const TemplateCreateInitial(),
    );

    Template? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  returned = await Navigator.of(ctx).push<Template>(
                    MaterialPageRoute<Template>(
                      // En prod showModalBottomSheet aporta el Material;
                      // aquí lo simula el Scaffold de la ruta empujada.
                      builder: (_) => BlocProvider<TemplateCreateBloc>.value(
                        value: bloc,
                        child: const Scaffold(body: TemplateCreateSheet()),
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
    expect(find.text('Nuevo Asistente'), findsOneWidget);

    controller.add(const TemplateCreateSucceeded(_tpl));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo Asistente'), findsNothing, reason: 'cerró');
    expect(returned, _tpl);
  });
}
