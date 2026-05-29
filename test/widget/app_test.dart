import 'package:agentic/app.dart';
import 'package:agentic/core/design/widgets/app_background.dart';
import 'package:agentic/core/router/app_router.dart';
import 'package:agentic/features/ai_catalog/domain/entities/catalog.dart';
import 'package:agentic/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:agentic/features/bots/domain/repositories/bots_repository.dart';
import 'package:agentic/features/flows/domain/repositories/flows_repository.dart';
import 'package:agentic/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:agentic/features/memberships/domain/entities/membership.dart';
import 'package:agentic/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockBotsRepo extends Mock implements BotsRepository {}

class _MockBotSessionRepo extends Mock implements BotSessionRepository {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

class _MockFlowsRepo extends Mock implements FlowsRepository {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockMembershipsRepo extends Mock implements MembershipsRepository {}

class _MockCatalogRepo extends Mock implements CatalogRepository {}

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
      templatesRepository: templatesRepo,
      flowsRepository: _MockFlowsRepo(),
      triggersRepository: _MockTriggersRepo(),
      membershipsRepository: membershipsRepo,
      catalogRepository: catalogRepo,
    );
  });

  testWidgets('AgenticApp cabla AppDesignTheme.dark() al MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(AgenticApp(router: router, authBloc: authBloc));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    // El scaffold es transparente: el fondo absoluto lo pinta AppBackground
    // (glow radial) detrás del navigator, no el color del scaffold.
    expect(app.theme?.scaffoldBackgroundColor, Colors.transparent);
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.theme?.brightness, Brightness.dark);
  });

  testWidgets('AgenticApp pinta el glow de fondo (AppBackground) detrás de '
      'todas las rutas vía el builder del MaterialApp', (tester) async {
    await tester.pumpWidget(AgenticApp(router: router, authBloc: authBloc));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.builder,
      isNotNull,
      reason: 'el builder envuelve el navigator para fijar el glow de fondo',
    );
    // El glow vive una sola vez, encima del navigator, fijo entre rutas.
    expect(find.byType(AppBackground), findsOneWidget);
  });

  testWidgets('AgenticApp no expone darkTheme separado (producto dark-only)', (
    tester,
  ) async {
    await tester.pumpWidget(AgenticApp(router: router, authBloc: authBloc));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, isNull);
  });
}
