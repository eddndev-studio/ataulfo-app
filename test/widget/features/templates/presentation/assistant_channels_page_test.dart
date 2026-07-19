import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_tile.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/template_detail_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/assistant_channels_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTemplateDetailBloc
    extends MockBloc<TemplateDetailEvent, TemplateDetailState>
    implements TemplateDetailBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

const _template = Template(
  id: 'assistant-1',
  orgId: 'org-1',
  name: 'Atención al cliente',
  version: 1,
  ai: AIConfig(
    enabled: true,
    provider: AIProvider.gemini,
    model: 'gemini-test',
    temperature: 0.5,
    thinkingLevel: ThinkingLevel.medium,
    systemPrompt: 'Ayuda al cliente.',
    contextMessages: 20,
  ),
);

const _activeChannel = Bot(
  id: 'channel-1',
  orgId: 'org-1',
  templateId: 'assistant-1',
  name: 'WhatsApp principal',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 1,
  paused: false,
  aiDisabled: false,
);

const _pausedChannel = Bot(
  id: 'channel-2',
  orgId: 'org-1',
  templateId: 'assistant-1',
  name: 'WhatsApp respaldo',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 1,
  paused: true,
  aiDisabled: false,
);

void main() {
  late _MockTemplateDetailBloc templateBloc;
  late _MockBotsBloc botsBloc;

  setUp(() {
    templateBloc = _MockTemplateDetailBloc();
    botsBloc = _MockBotsBloc();
    when(
      () => templateBloc.state,
    ).thenReturn(const TemplateDetailLoaded(_template));
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<TemplateDetailBloc>.value(value: templateBloc),
        BlocProvider<BotsBloc>.value(value: botsBloc),
      ],
      child: const AssistantChannelsPage(assistantId: 'assistant-1'),
    ),
  );

  testWidgets('carga de Asistente usa el estado canónico', (tester) async {
    when(() => templateBloc.state).thenReturn(const TemplateDetailLoading());

    await tester.pumpWidget(host());

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('fallo de Asistente usa el estado de error canónico', (
    tester,
  ) async {
    when(
      () => templateBloc.state,
    ).thenReturn(const TemplateDetailFailed(UnknownTemplatesFailure()));

    await tester.pumpWidget(host());

    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('fallo de Canales usa el estado de error canónico', (
    tester,
  ) async {
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsFailed(UnknownBotsFailure()));

    await tester.pumpWidget(host());

    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('lista vacía usa AppEmptyState', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('Aún no hay canales conectados'), findsOneWidget);
  });

  testWidgets('cada Canal reutiliza BotTile y la escala legible del listado', (
    tester,
  ) async {
    when(() => botsBloc.state).thenReturn(
      const BotsLoaded(items: <Bot>[_activeChannel], isRefreshing: false),
    );

    await tester.pumpWidget(host());

    expect(find.byType(BotTile), findsOneWidget);
    expect(
      find.byKey(const Key('assistant_channels.row.channel-1')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);

    final context = tester.element(find.byType(AssistantChannelsPage));
    final textTheme = Theme.of(context).textTheme;
    expect(
      tester.widget<Text>(find.text('WhatsApp principal')).style,
      textTheme.titleMedium,
    );
    expect(
      tester.widget<Text>(find.text('WhatsApp')).style,
      textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
    );
  });

  testWidgets('Canal pausado conserva el pill excepcional del componente', (
    tester,
  ) async {
    when(() => botsBloc.state).thenReturn(
      const BotsLoaded(items: <Bot>[_pausedChannel], isRefreshing: false),
    );

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
  });
}
