import 'dart:io';

import 'package:ataulfo/features/executions/domain/entities/execution.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/executions/domain/execution_repository.dart';
import 'package:ataulfo/app.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/design/widgets/app_background.dart';
import 'package:ataulfo/core/network/connectivity_cubit.dart';
import 'package:ataulfo/core/network/connectivity_monitor.dart';
import 'package:ataulfo/core/prefs/motion_settings_cubit.dart';
import 'package:ataulfo/core/router/app_router.dart';
import 'package:ataulfo/core/storage/secure_kv_store.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/org_ai_config/domain/repositories/org_ai_config_repository.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/messages/data/cache/message_media_cache.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/profile/data/cache/file_profile_photo_store.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/flow_run/domain/repositories/flow_run_repository.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/ai_log/domain/ai_log_repository.dart';
import 'package:ataulfo/features/notes/domain/repositories/notes_repository.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/quick_replies/domain/repositories/quick_replies_repository.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/media/data/repositories/noop_camera_capture.dart';
import 'package:ataulfo/features/media/data/repositories/noop_device_gallery.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:ataulfo/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/repositories/members_repository.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_chat_media.dart';
import '../support/fake_message_media_cache.dart';
import '../support/fake_thumbnail_loader.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockBotsRepo extends Mock implements BotsRepository {}

class _MockBotSessionRepo extends Mock implements BotSessionRepository {}

class _MockConversationsRepo extends Mock implements ConversationsRepository {}

class _MockMessagesRepo extends Mock implements MessagesRepository {}

class _MockProfileRepo extends Mock implements ProfileRepository {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

class _MockFlowsRepo extends Mock implements FlowsRepository {}

class _MockFlowRunRepo extends Mock implements FlowRunRepository {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

class _MockChatLabelsRepo extends Mock implements ChatLabelsRepository {}

class _MockNotesRepo extends Mock implements NotesRepository {}

class _MockAiLogRepo extends Mock implements AiLogRepository {}

class _MockTrainerRepo extends Mock implements TrainerRepository {}

class _MockWorkspaceRepo extends Mock implements WorkspaceRepository {}

class _MockPreviewRepo extends Mock implements PreviewRepository {}

class _MockPlatformAgentRepo extends Mock implements PlatformAgentRepository {}

class _MockPlatformAgentEvents extends Mock implements PlatformAgentEvents {}

class _MockTrainerEvents extends Mock implements TrainerEvents {}

class _FakeMonitorActivity
    implements MonitorActivityDatasource, MonitorBotActivityDatasource {
  @override
  Stream<MonitorEvent> activity(String botId, String chatLid) =>
      const Stream<MonitorEvent>.empty();

  @override
  Stream<MonitorEvent> botActivity(String botId) =>
      const Stream<MonitorEvent>.empty();
}

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

class _MockQuickRepliesRepo extends Mock implements QuickRepliesRepository {}

class _MockMembershipsRepo extends Mock implements MembershipsRepository {}

class _MockMembersRepo extends Mock implements MembersRepository {}

class _MockInvitationsRepo extends Mock implements InvitationsRepository {}

class _MockCatalogRepo extends Mock implements CatalogRepository {}

class _MockCalendarRepo extends Mock implements CalendarRepository {}

class _MockOrgAiConfigRepo extends Mock implements OrgAiConfigRepository {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockNotificationsRepo extends Mock implements NotificationsRepository {}

class _FakeMediaFilePicker implements MediaFilePicker {
  @override
  Future<PickedMedia?> pick() async => null;

  @override
  Future<List<PickedMedia>> pickMultiple() async => const <PickedMedia>[];
}

class _FakeExecutionsRepo implements ExecutionRepository {
  @override
  Future<List<Execution>> listBySession({
    required String botId,
    required String chatLid,
  }) async => const <Execution>[];
}

class _MemKv implements SecureKvStore {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

class _StubConnMonitor implements ConnectivityMonitor {
  @override
  Future<bool> isOnline() async => true;
  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

// Perfil sin foto: alimenta la caché de fotos del avatar sin tocar la red.
class _FakeProfileRepoNoPhoto implements ProfileRepository {
  @override
  Future<ChatProfile> fetch(String botId, String chatLid) async => ChatProfile(
    chatLid: chatLid,
    isGroup: false,
    phone: null,
    displayName: null,
    photoUrl: null,
    isArchived: false,
    isPinned: false,
    isMarkedUnread: false,
    mutedUntil: null,
  );
}

void main() {
  late _MockAuthBloc authBloc;
  late AppRouter router;
  late ConnectivityCubit connectivityCubit;
  late MotionSettingsCubit motionSettings;
  late ProfilePhotoCache profilePhotoCache;
  late MessageMediaCache messageMediaCache;
  late Directory photoTmp;

  setUp(() async {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthInitial());
    connectivityCubit = ConnectivityCubit(_StubConnMonitor());
    motionSettings = MotionSettingsCubit(_MemKv());
    photoTmp = await Directory.systemTemp.createTemp('app_test_photos');
    profilePhotoCache = ProfilePhotoCache(
      profileRepo: _FakeProfileRepoNoPhoto(),
      download: (_) async => null,
      store: FileProfilePhotoStore(directoryProvider: () async => photoTmp),
    );
    messageMediaCache = fakeMessageMediaCache();
    final botsRepo = _MockBotsRepo();
    final templatesRepo = _MockTemplatesRepo();
    final membershipsRepo = _MockMembershipsRepo();
    final membersRepo = _MockMembersRepo();
    final invitationsRepo = _MockInvitationsRepo();
    final catalogRepo = _MockCatalogRepo();
    final calendarRepo = _MockCalendarRepo();
    final orgAiConfigRepo = _MockOrgAiConfigRepo();
    final notificationsRepo = _MockNotificationsRepo();
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    when(templatesRepo.list).thenAnswer((_) async => const <Template>[]);
    when(membershipsRepo.list).thenAnswer((_) async => const <Membership>[]);
    when(membersRepo.list).thenAnswer((_) async => const <Member>[]);
    when(invitationsRepo.list).thenAnswer((_) async => const <Invitation>[]);
    when(
      catalogRepo.fetch,
    ).thenAnswer((_) async => const Catalog(providers: <ProviderEntry>[]));
    when(
      () => notificationsRepo.listInbox(unreadOnly: true),
    ).thenAnswer((_) async => const <NotificationInboxItem>[]);
    when(
      notificationsRepo.listPreferences,
    ).thenAnswer((_) async => const <NotificationPreference>[]);
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: _MockBotSessionRepo(),
      conversationsRepository: _MockConversationsRepo(),
      messagesRepository: _MockMessagesRepo(),
      templatesRepository: templatesRepo,
      flowsRepository: _MockFlowsRepo(),
      flowRunRepository: _MockFlowRunRepo(),
      triggersRepository: _MockTriggersRepo(),
      waLabelsRepository: _MockWaLabelsRepo(),
      quickRepliesRepository: _MockQuickRepliesRepo(),
      labelsRepository: _MockLabelsRepo(),
      chatLabelsRepository: _MockChatLabelsRepo(),
      notesRepository: _MockNotesRepo(),
      aiLogRepository: _MockAiLogRepo(),
      executionsRepository: _FakeExecutionsRepo(),
      trainerRepository: _MockTrainerRepo(),
      trainerEvents: _MockTrainerEvents(),
      monitorActivity: _FakeMonitorActivity(),
      monitorBotActivity: _FakeMonitorActivity(),
      workspaceRepository: _MockWorkspaceRepo(),
      previewRepository: _MockPreviewRepo(),
      platformAgentRepository: _MockPlatformAgentRepo(),
      platformAgentEvents: _MockPlatformAgentEvents(),
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      calendarRepository: calendarRepo,
      orgAiConfigRepository: orgAiConfigRepo,
      notificationsRepository: notificationsRepo,
      profileRepository: _MockProfileRepo(),
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      cameraCapture: const NoopCameraCapture(),
      deviceGallery: const NoopDeviceGallery(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      mediaOpener: const FakeMediaOpener(),
      mediaSharer: const FakeMediaSharer(),
      audioEngineFactory: FakeAudioEngine.new,
      audioRecorder: const NoopAudioRecorder(),
    );
  });

  tearDown(() async {
    await connectivityCubit.close();
    await motionSettings.close();
    if (photoTmp.existsSync()) await photoTmp.delete(recursive: true);
  });

  testWidgets('AtaulfoApp cabla AppDesignTheme.dark() al MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        connectivityCubit: connectivityCubit,
        profilePhotoCache: profilePhotoCache,
        messageMediaCache: messageMediaCache,
        motionSettings: motionSettings,
        onSignedOut: () {},
        onOrgChanged: () {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    // El scaffold es transparente: el fondo absoluto lo pinta AppBackground
    // (glow radial) detrás del navigator, no el color del scaffold.
    expect(app.theme?.scaffoldBackgroundColor, Colors.transparent);
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.theme?.brightness, Brightness.dark);
  });

  testWidgets('AtaulfoApp pinta el glow de fondo (AppBackground) detrás de '
      'todas las rutas vía el builder del MaterialApp', (tester) async {
    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        connectivityCubit: connectivityCubit,
        profilePhotoCache: profilePhotoCache,
        messageMediaCache: messageMediaCache,
        motionSettings: motionSettings,
        onSignedOut: () {},
        onOrgChanged: () {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.builder,
      isNotNull,
      reason: 'el builder envuelve el navigator para fijar el glow de fondo',
    );
    // El glow vive una sola vez, encima del navigator, fijo entre rutas.
    expect(find.byType(AppBackground), findsOneWidget);
  });

  testWidgets('AtaulfoApp no expone darkTheme separado (producto dark-only)', (
    tester,
  ) async {
    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        connectivityCubit: connectivityCubit,
        profilePhotoCache: profilePhotoCache,
        messageMediaCache: messageMediaCache,
        motionSettings: motionSettings,
        onSignedOut: () {},
        onOrgChanged: () {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, isNull);
  });

  // Higiene de sesión: el cache de media es un singleton de sesión; al cerrar
  // sesión hay que purgarlo o la próxima cuenta vería el catálogo de la
  // anterior sin reiniciar la app. AtaulfoApp dispara onSignedOut al caer a
  // Unauthenticated; la composición lo enchufa a MediaRepository.invalidate.
  testWidgets(
    'AtaulfoApp dispara onSignedOut al caer la sesión a Unauthenticated',
    (tester) async {
      var signedOut = 0;
      // Authenticated ANTES de Unauthenticated: el listener (listenWhen) debe
      // filtrar el primero y disparar SÓLO en el segundo. Si filtrara mal y
      // disparara en cada transición, signedOut sería 2 — por eso afirmamos
      // == 1 (no >= 1): cierra la mutación de un listenWhen permisivo.
      whenListen(
        authBloc,
        Stream<AuthState>.fromIterable(const <AuthState>[
          AuthAuthenticated(
            Identity(userId: 'u', orgId: 'o', role: 'OWNER', email: 'u@x'),
          ),
          AuthUnauthenticated(),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(
        AtaulfoApp(
          router: router,
          authBloc: authBloc,
          connectivityCubit: connectivityCubit,
          profilePhotoCache: profilePhotoCache,
          messageMediaCache: messageMediaCache,
          motionSettings: motionSettings,
          onSignedOut: () => signedOut++,
          onOrgChanged: () {},
        ),
      );
      await tester.pump(); // procesa Authenticated
      await tester.pump(); // procesa Unauthenticated

      expect(signedOut, 1);
    },
  );

  // El cambio de org activa (Authenticated org-A → Authenticated org-B) dispara
  // onOrgChanged (purga la verdad reconstruible, conserva el outbox), NO
  // onSignedOut. La detección vive en `isActiveOrgChange` (probada en
  // test/unit/app/is_active_org_change_test.dart); el `listenWhen` sólo admite
  // ese caso o Unauthenticated, así que el `else` del listener es onOrgChanged
  // por construcción. No se renderiza aquí el home autenticado (arrastra deps de
  // bandeja ajenas a esta frontera).

  testWidgets('con animaciones apagadas el theme usa transiciones '
      'instantáneas y AppMotion apaga el kit bajo el navigator', (
    tester,
  ) async {
    final motionOff = MotionSettingsCubit(_MemKv(), initial: false);
    addTearDown(motionOff.close);

    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        connectivityCubit: connectivityCubit,
        profilePhotoCache: profilePhotoCache,
        messageMediaCache: messageMediaCache,
        motionSettings: motionOff,
        onSignedOut: () {},
        onOrgChanged: () {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.theme?.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<AppInstantPageTransitionsBuilder>(),
    );
    // La señal ambiental envuelve el contenido del builder: cualquier widget
    // de cualquier ruta la ve apagada.
    expect(
      AppMotion.enabledOf(tester.element(find.byType(AppBackground))),
      isFalse,
    );
  });

  testWidgets('apagar animaciones en runtime reconstruye el theme al vuelo '
      '(apply-inmediato desde Apariencia)', (tester) async {
    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        connectivityCubit: connectivityCubit,
        profilePhotoCache: profilePhotoCache,
        messageMediaCache: messageMediaCache,
        motionSettings: motionSettings,
        onSignedOut: () {},
        onOrgChanged: () {},
      ),
    );

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app().theme?.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<FadeForwardsPageTransitionsBuilder>(),
    );

    await motionSettings.setEnabled(false);
    await tester.pump();

    expect(
      app().theme?.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<AppInstantPageTransitionsBuilder>(),
    );
  });
}
