import 'package:ataulfo/app.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/core/network/connectivity_cubit.dart';
import 'package:ataulfo/core/network/connectivity_monitor.dart';
import 'package:ataulfo/core/prefs/motion_settings_cubit.dart';
import 'package:ataulfo/core/router/app_router.dart';
import 'package:ataulfo/core/storage/secure_kv_store.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/org_ai_config/domain/repositories/org_ai_config_repository.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/flow_run/domain/repositories/flow_run_repository.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/ai_log/domain/ai_log_repository.dart';
import 'package:ataulfo/features/executions/domain/entities/execution.dart';
import 'package:ataulfo/features/executions/domain/execution_repository.dart';
import 'package:ataulfo/features/notes/domain/repositories/notes_repository.dart';
import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/platform_agent/domain/repositories/platform_agent_repository.dart';
import 'package:ataulfo/features/trainer/domain/repositories/trainer_repositories.dart';
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
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/quick_replies/domain/repositories/quick_replies_repository.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test/support/fake_chat_media.dart';
import '../test/support/fake_message_media_cache.dart';
import '../test/support/fake_thumbnail_loader.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _StubConnMonitor implements ConnectivityMonitor {
  @override
  Future<bool> isOnline() async => true;
  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

/// KV en memoria: el flujo bajo prueba no toca la preferencia de animaciones,
/// pero AtaulfoApp exige el cubit — hermético, sin Keystore real.
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

class _FakeExecutionsRepo implements ExecutionRepository {
  @override
  Future<List<Execution>> listBySession({
    required String botId,
    required String chatLid,
  }) async => const <Execution>[];
}

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

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('notifications → preferences navigation', (tester) async {
    final authBloc = _MockAuthBloc();
    final botsRepo = _MockBotsRepo();
    final templatesRepo = _MockTemplatesRepo();
    final labelsRepo = _MockLabelsRepo();
    final membershipsRepo = _MockMembershipsRepo();
    final membersRepo = _MockMembersRepo();
    final invitationsRepo = _MockInvitationsRepo();
    final catalogRepo = _MockCatalogRepo();
    final calendarRepo = _MockCalendarRepo();
    final orgAiConfigRepo = _MockOrgAiConfigRepo();
    final notificationsRepo = _MockNotificationsRepo();

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    when(templatesRepo.list).thenAnswer((_) async => const <Template>[]);
    when(labelsRepo.listLabels).thenAnswer((_) async => const <Label>[]);
    when(membershipsRepo.list).thenAnswer((_) async => const <Membership>[]);
    when(membersRepo.list).thenAnswer((_) async => const <Member>[]);
    when(invitationsRepo.list).thenAnswer((_) async => const <Invitation>[]);
    // El badge de cita del hilo consulta al abrir un chat; sin cita ⇒ oculto.
    when(
      () => calendarRepo.appointmentsByChat(
        botId: any(named: 'botId'),
        chatLid: any(named: 'chatLid'),
      ),
    ).thenAnswer((_) async => const <Appointment>[]);
    when(
      catalogRepo.fetch,
    ).thenAnswer((_) async => const Catalog(providers: <ProviderEntry>[]));
    when(
      () => notificationsRepo.listInbox(unreadOnly: true),
    ).thenAnswer((_) async => const <NotificationInboxItem>[]);
    when(
      notificationsRepo.listPreferences,
    ).thenAnswer((_) async => const <NotificationPreference>[]);

    final router = AppRouter(
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
      labelsRepository: labelsRepo,
      chatLabelsRepository: _MockChatLabelsRepo(),
      notesRepository: _MockNotesRepo(),
      aiLogRepository: _MockAiLogRepo(),
      executionsRepository: _FakeExecutionsRepo(),
      trainerRepository: _MockTrainerRepo(),
      trainerEvents: _MockTrainerEvents(),
      monitorActivity: _FakeMonitorActivity(),
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

    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        connectivityCubit: ConnectivityCubit(_StubConnMonitor()),
        motionSettings: MotionSettingsCubit(_MemKv()),
        profilePhotoCache: ProfilePhotoCache(
          profileRepo: _MockProfileRepo(),
          download: (_) async => null,
        ),
        messageMediaCache: fakeMessageMediaCache(),
        onSignedOut: () {},
        onOrgChanged: () {},
      ),
    );
    await _pumpUntil(tester, find.text('Bots'));

    router.router.go('/notifications');
    await _pumpUntil(tester, find.text('Sin notificaciones pendientes'));
    await tester.tap(find.text('Preferencias'));
    await _pumpUntil(tester, find.text('Sin preferencias configuradas'));

    expect(find.text('Sin preferencias configuradas'), findsOneWidget);
    verify(notificationsRepo.listPreferences).called(1);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('No apareció $finder en $timeout');
}
