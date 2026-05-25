import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/bots/domain/repositories/bots_repository.dart';
import '../../features/bots/presentation/bloc/bot_detail_bloc.dart';
import '../../features/bots/presentation/bloc/bots_bloc.dart';
import '../../features/bots/presentation/pages/bot_detail_page.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/templates/domain/repositories/templates_repository.dart';
import '../../features/templates/presentation/bloc/templates_bloc.dart';

/// Rutas de la app. La decisión de a qué ruta ir vive en el `redirect`
/// del GoRouter: lee el estado del `AuthBloc` global y mapea a `/`,
/// `/login` o `/home`. El Splash es un widget tonto.
///
/// `refreshListenable` se cabla al stream del bloc vía un `Listenable`
/// que invoca `notifyListeners()` en cada emisión. Cualquier transición
/// del estado de auth se traduce en una re-evaluación del redirect.
///
/// `/home` arma su propio `BotsBloc` page-scoped y dispara el primer load
/// al construirse. Cuando el shell con tabs aterrice, el bloc subirá al
/// nivel del shell para que la lista sobreviva al cambio de tab.
class AppRouter {
  AppRouter({
    required AuthBloc authBloc,
    required AuthRepository authRepository,
    required BotsRepository botsRepository,
    required TemplatesRepository templatesRepository,
  }) : _authBloc = authBloc,
       _authRepo = authRepository,
       _botsRepo = botsRepository,
       _templatesRepo = templatesRepository;

  final AuthBloc _authBloc;
  final AuthRepository _authRepo;
  final BotsRepository _botsRepo;
  final TemplatesRepository _templatesRepo;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthBlocListenable(_authBloc),
    redirect: _redirect,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(
        path: '/login',
        builder: (context, _) => BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(_authRepo),
          child: LoginPage(
            onSucceeded: (_) {
              // El verify dispara la transición a Authenticated y el
              // redirect navega a /home. Los tokens los acaba de
              // persistir el AuthRepository.login(); el bloc los lee
              // a través de hasTokens() + me().
              _authBloc.add(const AuthCheckRequested());
            },
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, _) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<BotsBloc>(
              create: (_) =>
                  BotsBloc(_botsRepo)..add(const BotsLoadRequested()),
            ),
            BlocProvider<TemplatesBloc>(
              create: (_) => TemplatesBloc(_templatesRepo)
                ..add(const TemplatesLoadRequested()),
            ),
          ],
          // Blocs page-scoped a nivel del shell: cambiar de tab no
          // rebuildea los providers y cada lista preserva estado
          // (Loaded, refresh, failures) entre Bots ⇄ Plantillas ⇄ Ajustes.
          child: const ShellPage(),
        ),
      ),
      GoRoute(
        path: '/bots/:id',
        builder: (context, state) {
          // El ID lo aporta el path param; el BotDetailBloc se construye
          // con ese ID y arranca cargando inmediato. Sin seed desde la
          // lista — la cache local (RFC-0001) será la que evite el flash
          // de spinner cuando aterrice.
          final id = state.pathParameters['id']!;
          return BlocProvider<BotDetailBloc>(
            create: (_) =>
                BotDetailBloc(repo: _botsRepo, id: id)
                  ..add(const BotDetailLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Detalle del bot')),
              body: const BotDetailPage(),
            ),
          );
        },
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = _authBloc.state;
    final location = state.matchedLocation;
    if (auth is AuthInitial) {
      // Hasta que el bloc decida, sólo dejamos pasar a `/` (Splash).
      // Cualquier intento de navegar directo a otra ruta antes del
      // primer check vuelve a / para evitar parpadeos.
      return location == '/' ? null : '/';
    }
    if (auth is AuthAuthenticated) {
      // Sesión válida: las rutas públicas redirigen a /home.
      return (location == '/' || location == '/login') ? '/home' : null;
    }
    // Unauthenticated: las rutas protegidas y el Splash van a /login.
    return location == '/login' ? null : '/login';
  }
}

/// Adapta el stream del bloc a un `Listenable` que GoRouter sabe
/// consumir. Cada emisión del bloc → `notifyListeners()` → re-evaluación
/// del `redirect`. Sin esto, el router sólo vería el estado al construirse.
class _AuthBlocListenable extends ChangeNotifier {
  _AuthBlocListenable(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Splash dumb: el AuthBloc decide la ruta vía redirect. Mientras tanto,
/// se muestra un spinner — no hay lógica aquí.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
