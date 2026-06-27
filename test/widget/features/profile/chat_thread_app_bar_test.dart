import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/widgets/chat_labels_sheet.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:ataulfo/features/flow_run/domain/entities/runnable_flow.dart';
import 'package:ataulfo/features/flow_run/domain/repositories/flow_run_repository.dart';
import 'package:ataulfo/features/flow_run/presentation/widgets/flow_run_sheet.dart';
import 'package:ataulfo/features/notes/domain/entities/note.dart';
import 'package:ataulfo/features/notes/domain/repositories/notes_repository.dart';
import 'package:ataulfo/features/notes/presentation/widgets/notes_sheet.dart';
import 'package:ataulfo/features/profile/presentation/widgets/chat_thread_app_bar.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_mapping.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

class _MockChatLabelsRepo extends Mock implements ChatLabelsRepository {}

class _MockFlowRunRepo extends Mock implements FlowRunRepository {}

class _MockNotesRepo extends Mock implements NotesRepository {}

class _FakeMonitorDs implements MonitorActivityDatasource {
  @override
  Stream<MonitorEvent> activity(String botId, String chatLid) =>
      const Stream<MonitorEvent>.empty();
}

void main() {
  late _MockProfileBloc bloc;
  late _MockAuthBloc auth;
  setUp(() {
    bloc = _MockProfileBloc();
    when(() => bloc.state).thenReturn(const ProfileInitial());
    // La entrada de observabilidad del app bar gatea por rol: el harness
    // arranca como WORKER (icono oculto); los tests del gate lo suben.
    auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(
      const AuthAuthenticated(
        Identity(userId: 'u1', email: 'x@x', orgId: 'o1', role: 'WORKER'),
      ),
    );
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileBloc>.value(value: bloc),
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<MonitorLiveCubit>(
          create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
        ),
      ],
      child: const Scaffold(
        appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
        body: SizedBox.shrink(),
      ),
    ),
  );

  testWidgets('cargado muestra el nombre real + avatar', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(AppAvatar), findsOneWidget);
  });

  testWidgets('mientras carga muestra un nombre neutro, nunca el JID crudo', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    // El chatLid es jerga de wire (p.ej. `34612@lid`): jamás se pinta en la
    // cabecera; mientras no hay identidad se comunica la espera.
    expect(find.text('lid-dm'), findsNothing);
    expect(find.text('Cargando…'), findsOneWidget);
  });

  testWidgets('grupo en carga: nombre neutro "Grupo" derivado del chatLid', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ProfileBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MonitorLiveCubit>(
              create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
            ),
          ],
          child: const Scaffold(
            appBar: ChatThreadAppBar(botId: 'b1', chatLid: '123-456@g.us'),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    expect(find.text('123-456@g.us'), findsNothing);
    expect(find.text('Grupo'), findsOneWidget);
  });

  testWidgets('el header es tappable (InkWell para abrir el perfil)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    // El header (bajo el Semantics "Ver perfil") es tappable; el botón de
    // etiquetas del app bar aporta su propio ink, así que se acota al header.
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.hint == 'Ver perfil',
        ),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
  });

  testWidgets('GROUP sin displayName cae a "Grupo"', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'g@g.us',
          isGroup: true,
          phone: null,
          displayName: null,
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Grupo'), findsOneWidget);
  });

  testWidgets('DM sin displayName cae al phone', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: null,
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('521555'), findsOneWidget);
  });

  testWidgets('el header se anuncia como botón con hint "Ver perfil"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    final sem = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.hint == 'Ver perfil',
      ),
    );
    expect(sem.properties.button, isTrue);
    expect(sem.properties.label, 'Alice');
  });

  group('etiquetas de WhatsApp', () {
    testWidgets('muestra el botón de etiquetas', (tester) async {
      when(() => bloc.state).thenReturn(const ProfileLoading());
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('thread.labels')), findsOneWidget);
    });

    testWidgets('tocar abre el sheet de etiquetas del chat', (tester) async {
      final waRepo = _MockWaLabelsRepo();
      when(
        () => waRepo.listCatalog(any()),
      ).thenAnswer((_) async => <WaLabel>[]);
      when(
        () => waRepo.listChatAssocs(any()),
      ).thenAnswer((_) async => <WaChatAssoc>[]);
      when(
        () => waRepo.listMappings(any()),
      ).thenAnswer((_) async => <WaLabelMapping>[]);
      when(
        () => waRepo.liveEvents(any()),
      ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
      final chatLabelsRepo = _MockChatLabelsRepo();
      when(
        () => chatLabelsRepo.listForChat(any(), any()),
      ).thenAnswer((_) async => <Label>[]);
      when(() => bloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<WaLabelsRepository>.value(value: waRepo),
              RepositoryProvider<ChatLabelsRepository>.value(
                value: chatLabelsRepo,
              ),
            ],
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProfileBloc>.value(value: bloc),
                BlocProvider<AuthBloc>.value(value: auth),
                BlocProvider<MonitorLiveCubit>(
                  create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
                ),
              ],
              child: const Scaffold(
                appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('thread.labels')));
      await tester.pumpAndSettle();
      expect(find.byType(ChatLabelsSheet), findsOneWidget);
    });
  });

  group('menú de acciones (⋮)', () {
    testWidgets('el botón de menú está visible (cualquier rol)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ProfileLoading());
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('thread.more')), findsOneWidget);
    });

    testWidgets('correr flujo y notas viven en el menú, no en la barra', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ProfileLoading());
      await tester.pumpWidget(host());
      // Cerrado: las acciones del menú no están en el árbol.
      expect(find.byKey(const Key('thread.run_flow')), findsNothing);
      expect(find.byKey(const Key('thread.notes')), findsNothing);
      // Abierto: aparecen como entradas del menú.
      await tester.tap(find.byKey(const Key('thread.more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thread.run_flow')), findsOneWidget);
      expect(find.byKey(const Key('thread.notes')), findsOneWidget);
    });
  });

  group('correr flujo', () {
    testWidgets('tocar la entrada del menú abre el sheet de correr flujo', (
      tester,
    ) async {
      final runRepo = _MockFlowRunRepo();
      when(
        () => runRepo.listRunnable(any()),
      ).thenAnswer((_) async => <RunnableFlow>[]);
      when(() => bloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: RepositoryProvider<FlowRunRepository>.value(
            value: runRepo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProfileBloc>.value(value: bloc),
                BlocProvider<AuthBloc>.value(value: auth),
                BlocProvider<MonitorLiveCubit>(
                  create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
                ),
              ],
              child: const Scaffold(
                appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('thread.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thread.run_flow')));
      await tester.pumpAndSettle();
      expect(find.byType(FlowRunSheet), findsOneWidget);
    });
  });

  group('notas', () {
    testWidgets('tocar la entrada del menú abre el sheet de notas', (
      tester,
    ) async {
      final notesRepo = _MockNotesRepo();
      when(
        () => notesRepo.listChatNotes(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
        ),
      ).thenAnswer((_) async => <Note>[]);
      when(() => bloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: RepositoryProvider<NotesRepository>.value(
            value: notesRepo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProfileBloc>.value(value: bloc),
                BlocProvider<AuthBloc>.value(value: auth),
                BlocProvider<MonitorLiveCubit>(
                  create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
                ),
              ],
              child: const Scaffold(
                appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('thread.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thread.notes')));
      await tester.pumpAndSettle();
      expect(find.byType(NotesSheet), findsOneWidget);
    });
  });

  group('observabilidad en el menú (solo ADMIN)', () {
    testWidgets('WORKER: el menú no lista las entradas de observabilidad', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('thread.more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thread.ai_log')), findsNothing);
      expect(find.byKey(const Key('thread.ai_ledger')), findsNothing);
      expect(find.byKey(const Key('thread.executions')), findsNothing);
      // Pero el menú NO queda vacío: correr flujo y notas siguen ahí.
      expect(find.byKey(const Key('thread.run_flow')), findsOneWidget);
      expect(find.byKey(const Key('thread.notes')), findsOneWidget);
    });

    testWidgets('ADMIN: el menú lista razonamiento, bitácora y ejecuciones', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(
        const AuthAuthenticated(
          Identity(userId: 'u1', email: 'x@x', orgId: 'o1', role: 'ADMIN'),
        ),
      );
      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('thread.more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('thread.ai_log')), findsOneWidget);
      expect(find.byKey(const Key('thread.ai_ledger')), findsOneWidget);
      expect(find.byKey(const Key('thread.executions')), findsOneWidget);
    });
  });

  group('navegación de observabilidad (solo ADMIN)', () {
    // Cada entrada del menú empuja una ruta distinta: si una quedara cableada a
    // la URL de otra, este test la detecta (cada destino tiene un marcador
    // único). Cubre por comportamiento las 3 ramas de navegación del menú, a la
    // par de correr flujo/notas que ya se prueban tocando.
    GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
            body: SizedBox.shrink(),
          ),
        ),
        GoRoute(
          path: '/bots/:botId/sessions/:chatLid/ai-log',
          builder: (_, _) => const Text('PAGE_AI_LOG'),
        ),
        GoRoute(
          path: '/bots/:botId/sessions/:chatLid/ai-ledger',
          builder: (_, _) => const Text('PAGE_AI_LEDGER'),
        ),
        GoRoute(
          path: '/bots/:botId/sessions/:chatLid/executions',
          builder: (_, _) => const Text('PAGE_EXECUTIONS'),
        ),
      ],
    );

    Future<void> expectNavigates(
      WidgetTester tester,
      String itemKey,
      String pageText,
    ) async {
      when(() => auth.state).thenReturn(
        const AuthAuthenticated(
          Identity(userId: 'u1', email: 'x@x', orgId: 'o1', role: 'ADMIN'),
        ),
      );
      when(() => bloc.state).thenReturn(const ProfileLoading());
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ProfileBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<MonitorLiveCubit>(
              create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
            ),
          ],
          child: MaterialApp.router(
            theme: AppDesignTheme.dark(),
            routerConfig: buildRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thread.more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(itemKey)));
      await tester.pumpAndSettle();
      expect(find.text(pageText), findsOneWidget);
    }

    testWidgets('Razonamiento del bot navega a ai-log', (tester) async {
      await expectNavigates(tester, 'thread.ai_log', 'PAGE_AI_LOG');
    });

    testWidgets('Bitácora de acciones navega a ai-ledger', (tester) async {
      await expectNavigates(tester, 'thread.ai_ledger', 'PAGE_AI_LEDGER');
    });

    testWidgets('Ejecuciones del chat navega a executions', (tester) async {
      await expectNavigates(tester, 'thread.executions', 'PAGE_EXECUTIONS');
    });
  });

  group('toma del chat (takeover)', () {
    testWidgets('WORKER no ve el control del bot', (tester) async {
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('thread.takeover')), findsNothing);
    });

    testWidgets('ADMIN ve el control del bot', (tester) async {
      when(() => auth.state).thenReturn(
        const AuthAuthenticated(
          Identity(userId: 'u1', email: 'x@x', orgId: 'o1', role: 'ADMIN'),
        ),
      );
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('thread.takeover')), findsOneWidget);
    });
  });
}
