import 'package:ataulfo/app.dart';
import 'package:ataulfo/core/design/widgets/app_background.dart';
import 'package:ataulfo/core/router/app_router.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockMembershipsRepo extends Mock implements MembershipsRepository {}

class _MockCatalogRepo extends Mock implements CatalogRepository {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _FakeMediaFilePicker implements MediaFilePicker {
  @override
  Future<PickedMedia?> pick() async => null;
}

void main() {
  late _MockAuthBloc authBloc;
  late AppRouter router;

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthInitial());
    final botsRepo = _MockBotsRepo();
    final templatesRepo = _MockTemplatesRepo();
    final membershipsRepo = _MockMembershipsRepo();
    final catalogRepo = _MockCatalogRepo();
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    when(templatesRepo.list).thenAnswer((_) async => const <Template>[]);
    when(membershipsRepo.list).thenAnswer((_) async => const <Membership>[]);
    when(
      catalogRepo.fetch,
    ).thenAnswer((_) async => const Catalog(providers: <ProviderEntry>[]));
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: _MockBotSessionRepo(),
      conversationsRepository: _MockConversationsRepo(),
      messagesRepository: _MockMessagesRepo(),
      templatesRepository: templatesRepo,
      flowsRepository: _MockFlowsRepo(),
      triggersRepository: _MockTriggersRepo(),
      membershipsRepository: membershipsRepo,
      catalogRepository: catalogRepo,
      profileRepository: _MockProfileRepo(),
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
    );
  });

  testWidgets('AtaulfoApp cabla AppDesignTheme.dark() al MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(AtaulfoApp(router: router, authBloc: authBloc, onSignedOut: () {}));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    // El scaffold es transparente: el fondo absoluto lo pinta AppBackground
    // (glow radial) detrás del navigator, no el color del scaffold.
    expect(app.theme?.scaffoldBackgroundColor, Colors.transparent);
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.theme?.brightness, Brightness.dark);
  });

  testWidgets('AtaulfoApp pinta el glow de fondo (AppBackground) detrás de '
      'todas las rutas vía el builder del MaterialApp', (tester) async {
    await tester.pumpWidget(AtaulfoApp(router: router, authBloc: authBloc, onSignedOut: () {}));

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
    await tester.pumpWidget(AtaulfoApp(router: router, authBloc: authBloc, onSignedOut: () {}));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, isNull);
  });

  // Higiene de sesión: el cache de media es un singleton de sesión; al cerrar
  // sesión hay que purgarlo o la próxima cuenta vería el catálogo de la
  // anterior sin reiniciar la app. AtaulfoApp dispara onSignedOut al caer a
  // Unauthenticated; la composición lo enchufa a MediaRepository.invalidate.
  testWidgets('AtaulfoApp dispara onSignedOut al caer la sesión a Unauthenticated', (
    tester,
  ) async {
    var signedOut = 0;
    whenListen(
      authBloc,
      Stream<AuthState>.fromIterable(const <AuthState>[AuthUnauthenticated()]),
      initialState: const AuthInitial(),
    );

    await tester.pumpWidget(
      AtaulfoApp(
        router: router,
        authBloc: authBloc,
        onSignedOut: () => signedOut++,
      ),
    );
    await tester.pump(); // procesa la emisión Unauthenticated

    expect(signedOut, 1);
  });
}
