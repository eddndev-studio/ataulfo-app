import 'package:ataulfo/app.dart';
import 'package:ataulfo/core/router/app_router.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/repositories/members_repository.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test/support/fake_thumbnail_loader.dart';

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

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

class _MockMembershipsRepo extends Mock implements MembershipsRepository {}

class _MockMembersRepo extends Mock implements MembersRepository {}

class _MockCatalogRepo extends Mock implements CatalogRepository {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockNotificationsRepo extends Mock implements NotificationsRepository {}

class _FakeMediaFilePicker implements MediaFilePicker {
  @override
  Future<PickedMedia?> pick() async => null;
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
    final catalogRepo = _MockCatalogRepo();
    final notificationsRepo = _MockNotificationsRepo();

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    when(templatesRepo.list).thenAnswer((_) async => const <Template>[]);
    when(labelsRepo.listLabels).thenAnswer((_) async => const <Label>[]);
    when(membershipsRepo.list).thenAnswer((_) async => const <Membership>[]);
    when(membersRepo.list).thenAnswer((_) async => const <Member>[]);
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
      triggersRepository: _MockTriggersRepo(),
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      profileRepository: _MockProfileRepo(),
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
    );

    await tester.pumpWidget(
      AtaulfoApp(router: router, authBloc: authBloc, onSignedOut: () {}),
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
