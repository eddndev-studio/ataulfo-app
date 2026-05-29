import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_detail_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotDetailBloc extends MockBloc<BotDetailEvent, BotDetailState>
    implements BotDetailBloc {}

const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotDetailLoadRequested());
  });

  late _MockBotDetailBloc bloc;

  setUp(() {
    bloc = _MockBotDetailBloc();
    when(() => bloc.state).thenReturn(const BotDetailLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<BotDetailBloc>.value(
      value: bloc,
      // BotDetailPage es content-only; el host envuelve en Scaffold para
      // dar Material upstream a los widgets internos.
      child: const Scaffold(body: BotDetailPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const BotDetailLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded muestra nombre, canal y AppAvatar(size: 64)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    // El header usa AppAvatar grande (no CircleAvatar de Material).
    final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
    expect(avatar.size, 64);
    expect(avatar.name, 'Soporte');
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('Loaded muestra version como AppPill.outline', (tester) async {
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

    await tester.pumpWidget(host());

    // La versión sale del modelo CAS: el operador la lee para sospechar
    // colisiones si reporta un bug post-edit. Migra a Pill outline para
    // no traer Chip de Material al detalle.
    expect(find.widgetWithText(AppPill, 'v3'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('Loaded(paused=false) muestra AppPill primary "Activo"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'Activo'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'Pausado'), findsNothing);
  });

  testWidgets('Loaded(paused=true) muestra AppPill neutral "Pausado"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const BotDetailLoaded(
        Bot(
          id: 'b2',
          orgId: 'o1',
          templateId: 't1',
          name: 'Cobranza',
          channel: BotChannel.waba,
          identifier: null,
          version: 1,
          paused: true,
          aiDisabled: false,
        ),
      ),
    );

    await tester.pumpWidget(host());

    // Copy alineado con bots/list ('Pausado'); el detalle no podía decir
    // 'En pausa' cuando el listado dice otra cosa para el mismo estado.
    expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
    expect(find.text('En pausa'), findsNothing);
    // El icono pause_circle legacy desaparece — el estado vive en el pill.
    expect(find.byIcon(Icons.pause_circle), findsNothing);
  });

  testWidgets(
    'Loaded(aiDisabled=true) muestra AppPill neutral "IA deshabilitada"',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const BotDetailLoaded(
          Bot(
            id: 'b3',
            orgId: 'o1',
            templateId: 't1',
            name: 'X',
            channel: BotChannel.waba,
            identifier: null,
            version: 1,
            paused: false,
            aiDisabled: true,
          ),
        ),
      );

      await tester.pumpWidget(host());

      // IA off es estado de configuración, no error → neutral (no danger).
      expect(find.widgetWithText(AppPill, 'IA deshabilitada'), findsOneWidget);
    },
  );

  testWidgets('Loaded(aiDisabled=false) NO muestra pill de IA', (tester) async {
    when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'IA deshabilitada'), findsNothing);
  });

  testWidgets('Failed con NotFound preserva key y usa AppButton "Reintentar"', (
    tester,
  ) async {
    // El detalle es la primera pantalla que distingue NotFound del genérico:
    // un ID inválido o borrado merece un copy honesto, no "algo falló".
    when(
      () => bloc.state,
    ).thenReturn(const BotDetailFailed(BotsNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_detail.error.not_found')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Failed con otra failure preserva key genérica + Reintentar', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotDetailFailed(BotsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bot_detail.error.generic')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara BotDetailLoadRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotDetailFailed(BotsServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const BotDetailLoadRequested())).called(1);
  });
}
