import 'package:agentic/core/router/app_router.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/auth/presentation/pages/login_page.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/repositories/bots_repository.dart';
import 'package:agentic/features/bots/presentation/pages/bot_detail_page.dart';
import 'package:agentic/features/bots/presentation/pages/bots_list_page.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/repositories/templates_repository.dart';
import 'package:agentic/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockBotsRepo extends Mock implements BotsRepository {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

const _identity = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');

Widget _host(AppRouter router, AuthBloc authBloc) =>
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router.router),
    );

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsRepo botsRepo;
  late _MockTemplatesRepo templatesRepo;
  late AppRouter router;

  setUp(() {
    authBloc = _MockAuthBloc();
    botsRepo = _MockBotsRepo();
    templatesRepo = _MockTemplatesRepo();
    // Los blocs page-scoped del shell arrancan con LoadRequested al
    // construirse; los repos mock devuelven listas vacías para que los
    // loads terminen sin colgar el pumpAndSettle.
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    when(templatesRepo.list).thenAnswer((_) async => const <Template>[]);
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      templatesRepository: templatesRepo,
    );
  });

  testWidgets('AuthInitial → Splash (CircularProgressIndicator)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthInitial());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /home muestra BotsListPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(BotsListPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /home expone TemplatesBloc al árbol', (
    tester,
  ) async {
    // El provider del TemplatesBloc vive en el route builder de /home (no
    // dentro de cada tab) para preservarlo entre cambios de tab. Si lo
    // mueven adentro del shell, este test rompe — guarda el contrato.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    // Leer el bloc desde el árbol del BotsListPage (tab activa por
    // default) confirma que el provider está aguas arriba del shell.
    final templatesBloc = tester
        .element(find.byType(BotsListPage))
        .read<TemplatesBloc>();
    expect(templatesBloc, isNotNull);
    // El bloc dispara LoadRequested al construirse; el repo mock responde
    // con [] y el bloc termina en Loaded(empty). pumpAndSettle ya esperó
    // la transición.
    verify(templatesRepo.list).called(1);
  });

  testWidgets('AuthUnauthenticated → redirige a LoginPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets(
    'cambio de estado dispara refreshListenable y re-evalúa redirect',
    (tester) async {
      whenListen(
        authBloc,
        Stream<AuthState>.fromIterable(const <AuthState>[
          AuthUnauthenticated(),
          AuthAuthenticated(_identity),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(BotsListPage), findsOneWidget);
    },
  );

  testWidgets('AuthAuthenticated → /bots/:id muestra BotDetailPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    // El BotDetailBloc de la ruta arranca con LoadRequested al construirse;
    // el repo mock devuelve un Bot para que el load termine sin colgar
    // pumpAndSettle.
    when(() => botsRepo.byId('b1')).thenAnswer(
      (_) async => const Bot(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: BotChannel.waUnofficial,
        identifier: '52155...',
        version: 3,
        paused: false,
        aiDisabled: false,
      ),
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1');
    await tester.pumpAndSettle();

    expect(find.byType(BotDetailPage), findsOneWidget);
    verify(() => botsRepo.byId('b1')).called(1);
  });

  testWidgets('AuthUnauthenticated + ruta protegida cualquiera → /login', (
    tester,
  ) async {
    // El redirect no debe asumir que /home es el único destino protegido:
    // cualquier ruta no pública (p. ej. /bots/:id por deep-link) tiene que
    // mandar a /login si no hay sesión.
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      templatesRepository: templatesRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(BotDetailPage), findsNothing);
  });
}
