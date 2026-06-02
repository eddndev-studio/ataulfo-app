import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_detail_page.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotDetailBloc extends MockBloc<BotDetailEvent, BotDetailState>
    implements BotDetailBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

Identity _identity(String role) =>
    Identity(userId: 'u1', orgId: 'o1', role: role, email: 'op@org.test');

Template _tmpl({required bool aiEnabled}) => Template(
  id: 't1',
  orgId: 'o1',
  name: 'Plantilla',
  version: 1,
  ai: AIConfig(
    enabled: aiEnabled,
    provider: AIProvider.openai,
    model: 'gpt',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.medium,
    systemPrompt: '',
    contextMessages: 10,
  ),
);

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
  late _MockAuthBloc authBloc;
  late _MockTemplatesRepo templatesRepo;

  setUp(() {
    bloc = _MockBotDetailBloc();
    when(() => bloc.state).thenReturn(const BotDetailLoading());
    authBloc = _MockAuthBloc();
    when(
      () => authBloc.state,
    ).thenReturn(AuthAuthenticated(_identity('ADMIN')));
    templatesRepo = _MockTemplatesRepo();
    // El toggle de IA (S4) lee Template.ai.enabled SOLO en el render ADMIN+.
    when(
      () => templatesRepo.byId(any()),
    ).thenAnswer((_) async => _tmpl(aiEnabled: true));
  });

  // El gateo ADMIN+ lee el rol del AuthBloc del scope; por defecto ADMIN
  // (ve los controles). `role` lo baja a WORKER para los casos de gateo.
  // El `TemplatesRepository` cuelga del scope (RepositoryProvider) para el
  // toggle de IA; sólo el render ADMIN+ lo consume (MAJOR 1).
  Widget host({String role = 'ADMIN'}) {
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_identity(role)));
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: RepositoryProvider<TemplatesRepository>.value(
        value: templatesRepo,
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<BotDetailBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          // BotDetailPage es content-only; el host envuelve en Scaffold para
          // dar Material upstream a los widgets internos.
          child: const Scaffold(body: BotDetailPage()),
        ),
      ),
    );
  }

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

  group('toggle Pausar (S2, ADMIN+)', () {
    setUpAll(() {
      registerFallbackValue(const BotDetailUpdateRequested());
    });

    testWidgets('ADMIN ve el AppSwitch de pausa con value=bot.paused', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());

      final sw = tester.widget<AppSwitch>(
        find.byKey(const Key('bot_detail.paused')),
      );
      // _bot.paused == false → el switch arranca apagado.
      expect(sw.value, isFalse);
      expect(sw.onChanged, isNotNull);
    });

    testWidgets('WORKER NO ve el switch de pausa (gateo ADMIN+)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host(role: 'WORKER'));

      expect(find.byKey(const Key('bot_detail.paused')), findsNothing);
    });

    testWidgets('tap en el switch despacha UpdateRequested(paused: true)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('bot_detail.paused')));
      await tester.pump();

      verify(
        () => bloc.add(const BotDetailUpdateRequested(paused: true)),
      ).called(1);
    });

    testWidgets('Mutating deshabilita el switch (onChanged null)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailMutating(_bot));

      await tester.pumpWidget(host());

      final sw = tester.widget<AppSwitch>(
        find.byKey(const Key('bot_detail.paused')),
      );
      expect(sw.onChanged, isNull);
    });

    testWidgets('MutationFailed(conflict) muestra copy de desactualizado', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const BotDetailMutationFailed(_bot, BotsConflictFailure()));

      await tester.pumpWidget(host());

      // El switch sigue visible (snapshot) y aparece el copy de conflicto.
      expect(find.byKey(const Key('bot_detail.paused')), findsOneWidget);
      expect(find.textContaining('desactualizada'), findsOneWidget);
    });
  });

  group('editar nombre (S3, ADMIN+)', () {
    testWidgets('ADMIN ve el lápiz; tap abre BotEditSheet', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      expect(find.byKey(const Key('bot_detail.edit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bot_detail.edit')));
      await tester.pumpAndSettle();
      expect(find.text('Editar bot'), findsOneWidget);
      expect(find.byKey(const Key('bot_edit.name')), findsOneWidget);
    });

    testWidgets('WORKER no ve el lápiz', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host(role: 'WORKER'));

      expect(find.byKey(const Key('bot_detail.edit')), findsNothing);
    });
  });

  group('toggle Deshabilitar IA (S4, ADMIN+, IA efectiva)', () {
    testWidgets('ADMIN + template.ai.enabled: switch IA operable', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final sw = tester.widget<AppSwitch>(
        find.byKey(const Key('bot_detail.ai')),
      );
      // _bot.aiDisabled == false → el switch "Deshabilitar IA" arranca apagado.
      expect(sw.value, isFalse);
      expect(sw.onChanged, isNotNull);
    });

    testWidgets(
      'WORKER NO ve el switch IA y NO fetchea la Template (MAJOR 1)',
      (tester) async {
        when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

        await tester.pumpWidget(host(role: 'WORKER'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('bot_detail.ai')), findsNothing);
        // La carga compartida NUNCA toca el endpoint ADMIN+ de Template.
        verifyNever(() => templatesRepo.byId(any()));
      },
    );

    testWidgets('tap en el switch IA despacha UpdateRequested(aiDisabled)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bot_detail.ai')));
      await tester.pump();

      verify(
        () => bloc.add(const BotDetailUpdateRequested(aiDisabled: true)),
      ).called(1);
    });

    testWidgets('template.ai.enabled=false → switch IA inerte + explicado', (
      tester,
    ) async {
      when(
        () => templatesRepo.byId(any()),
      ).thenAnswer((_) async => _tmpl(aiEnabled: false));
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final sw = tester.widget<AppSwitch>(
        find.byKey(const Key('bot_detail.ai')),
      );
      expect(sw.onChanged, isNull); // inerte
      expect(find.textContaining('plantilla'), findsWidgets);
    });

    testWidgets('fetch de Template falla → switch IA sigue operable', (
      tester,
    ) async {
      when(
        () => templatesRepo.byId(any()),
      ).thenAnswer((_) => Future<Template>.error(const _Boom()));
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final sw = tester.widget<AppSwitch>(
        find.byKey(const Key('bot_detail.ai')),
      );
      // Degrada sin falsear: el flag del bot es real, el toggle sigue operable.
      expect(sw.onChanged, isNotNull);
    });
  });

  group('navegación a sub-páginas ADMIN+ (S6)', () {
    testWidgets('ADMIN ve el botón Variables', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bot_detail.variables')), findsOneWidget);
    });

    testWidgets('WORKER no ve el botón Variables', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host(role: 'WORKER'));

      expect(find.byKey(const Key('bot_detail.variables')), findsNothing);
    });

    testWidgets('ADMIN ve el botón Mantenimiento', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bot_detail.maintenance')), findsOneWidget);
    });

    testWidgets('WORKER no ve el botón Mantenimiento', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host(role: 'WORKER'));

      expect(find.byKey(const Key('bot_detail.maintenance')), findsNothing);
    });
  });

  group('clonar (S7, ADMIN+)', () {
    testWidgets('ADMIN ve Clonar bot; tap abre BotCloneSheet', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final clone = find.byKey(const Key('bot_detail.clone'));
      expect(clone, findsOneWidget);

      await tester.ensureVisible(clone);
      await tester.tap(clone);
      await tester.pumpAndSettle();
      expect(find.text('Clonar bot'), findsWidgets);
      expect(find.byKey(const Key('bot_clone.name')), findsOneWidget);
    });

    testWidgets('WORKER no ve Clonar bot', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host(role: 'WORKER'));

      expect(find.byKey(const Key('bot_detail.clone')), findsNothing);
    });
  });

  group('eliminar (S8, ADMIN+, Tier B)', () {
    setUpAll(() {
      registerFallbackValue(const BotDetailDeleteRequested());
    });

    testWidgets('ADMIN: tap Eliminar → confirma → BotDetailDeleteRequested', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final del = find.byKey(const Key('bot_detail.delete'));
      await tester.ensureVisible(del);
      await tester.tap(del);
      await tester.pumpAndSettle();

      // Diálogo de confirmación fuerte: avisa de huérfanos.
      expect(find.textContaining('huérfan'), findsOneWidget);
      // Sin confirmar aún → no despacha.
      verifyNever(() => bloc.add(const BotDetailDeleteRequested()));

      await tester.tap(find.byKey(const Key('bot_detail.delete_confirm')));
      await tester.pump();
      verify(() => bloc.add(const BotDetailDeleteRequested())).called(1);
    });

    testWidgets('cancelar el diálogo NO despacha', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('bot_detail.delete')));
      await tester.tap(find.byKey(const Key('bot_detail.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pump();

      verifyNever(() => bloc.add(const BotDetailDeleteRequested()));
    });

    testWidgets('WORKER no ve Eliminar bot', (tester) async {
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));

      await tester.pumpWidget(host(role: 'WORKER'));

      expect(find.byKey(const Key('bot_detail.delete')), findsNothing);
    });

    testWidgets('DeleteSucceeded → hace pop de la página', (tester) async {
      final ctrl = StreamController<BotDetailState>.broadcast();
      addTearDown(ctrl.close);
      when(() => bloc.state).thenReturn(const BotDetailLoaded(_bot));
      whenListen(bloc, ctrl.stream, initialState: const BotDetailLoaded(_bot));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RepositoryProvider<TemplatesRepository>.value(
                          value: templatesRepo,
                          child: MultiBlocProvider(
                            providers: <BlocProvider<dynamic>>[
                              BlocProvider<BotDetailBloc>.value(value: bloc),
                              BlocProvider<AuthBloc>.value(value: authBloc),
                            ],
                            child: const Scaffold(body: BotDetailPage()),
                          ),
                        ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BotDetailPage), findsOneWidget);

      ctrl.add(const BotDetailDeleteSucceeded());
      await tester.pumpAndSettle();
      expect(find.byType(BotDetailPage), findsNothing);
    });
  });
}

class _Boom implements Exception {
  const _Boom();
}
