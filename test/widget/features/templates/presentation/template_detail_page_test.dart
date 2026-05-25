import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:agentic/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:agentic/features/templates/presentation/pages/template_detail_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<TemplateDetailEvent, TemplateDetailState>
    implements TemplateDetailBloc {}

const _tpl = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 3,
  ai: AIConfig(
    enabled: true,
    provider: AIProvider.gemini,
    model: 'gemini-3.1-pro-preview',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.medium,
    systemPrompt: 'Eres un asistente de soporte amable.',
    contextMessages: 20,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplateDetailLoadRequested());
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());
  });

  Widget host() => MaterialApp(
    home: BlocProvider<TemplateDetailBloc>.value(
      value: bloc,
      // TemplateDetailPage es content-only; el host envuelve en Scaffold
      // para dar Material upstream a Chip/FilledButton/etc.
      child: const Scaffold(body: TemplateDetailPage()),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoading());

    await tester.pumpWidget(host());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Loaded muestra name + version + provider humanizado', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('v3'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
  });

  testWidgets(
    'Loaded muestra todos los campos AIConfig (provider/model/temp/think/ctx)',
    (tester) async {
      when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

      await tester.pumpWidget(host());

      // Provider y modelo (texto crudo del wire — es identificador técnico,
      // no se humaniza).
      expect(find.text('gemini-3.1-pro-preview'), findsOneWidget);
      // Temperatura con un decimal.
      expect(find.textContaining('0.7'), findsWidgets);
      // Thinking level humanizado.
      expect(find.text('Medio'), findsOneWidget);
      // Mensajes de contexto.
      expect(find.textContaining('20'), findsWidgets);
    },
  );

  testWidgets('Loaded(enabled=true) muestra estado "IA habilitada"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    expect(find.text('IA habilitada'), findsOneWidget);
  });

  testWidgets('Loaded(enabled=false) muestra estado "IA deshabilitada"', (
    tester,
  ) async {
    const tplOff = Template(
      id: 't2',
      orgId: 'o1',
      name: 'Marketing',
      version: 1,
      ai: AIConfig(
        enabled: false,
        provider: AIProvider.openai,
        model: 'gpt-5-pro',
        temperature: 1.0,
        thinkingLevel: ThinkingLevel.low,
        systemPrompt: '',
        contextMessages: 10,
      ),
    );
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplOff));

    await tester.pumpWidget(host());

    expect(find.text('IA deshabilitada'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Bajo'), findsOneWidget);
  });

  testWidgets('Loaded con systemPrompt no vacío lo muestra (SelectableText)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(_tpl));

    await tester.pumpWidget(host());

    // El system prompt es contenido del usuario; debe ser seleccionable
    // para que se pueda copiar.
    expect(find.text('Eres un asistente de soporte amable.'), findsOneWidget);
  });

  testWidgets('Failed(NotFound) muestra mensaje específico + retry', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_detail.error.not_found')),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Failed(Network) muestra mensaje genérico + retry', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesNetworkFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('template_detail.error.generic')),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('tap en Reintentar dispara TemplateDetailLoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplateDetailFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const TemplateDetailLoadRequested())).called(1);
  });

  testWidgets('proveedor MiniMax se humaniza correctamente', (tester) async {
    const tplMx = Template(
      id: 't3',
      orgId: 'o1',
      name: 'X',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.minimax,
        model: 'minimax-m1-80k',
        temperature: 0.5,
        thinkingLevel: ThinkingLevel.high,
        systemPrompt: '',
        contextMessages: 5,
      ),
    );
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplMx));

    await tester.pumpWidget(host());

    expect(find.text('MiniMax'), findsOneWidget);
    expect(find.text('Alto'), findsOneWidget);
  });

  testWidgets('proveedor DeepSeek se humaniza correctamente', (tester) async {
    const tplDs = Template(
      id: 't4',
      orgId: 'o1',
      name: 'X',
      version: 1,
      ai: AIConfig(
        enabled: true,
        provider: AIProvider.deepseek,
        model: 'deepseek-chat',
        temperature: 0.8,
        thinkingLevel: ThinkingLevel.medium,
        systemPrompt: '',
        contextMessages: 8,
      ),
    );
    when(() => bloc.state).thenReturn(const TemplateDetailLoaded(tplDs));

    await tester.pumpWidget(host());

    expect(find.text('DeepSeek'), findsOneWidget);
  });
}
