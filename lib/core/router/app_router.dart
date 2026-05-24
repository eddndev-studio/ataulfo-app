import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';

/// Rutas de la app. La decisión de a qué ruta ir vive en el `redirect`
/// del GoRouter: lee el estado del `AuthBloc` global y mapea a `/`,
/// `/login` o `/home`. El Splash es ahora un widget tonto — sólo
/// muestra spinner mientras el bloc está en `AuthInitial`.
///
/// `refreshListenable` se cabla al stream del bloc vía un `Listenable`
/// que invoca `notifyListeners()` en cada emisión. Cualquier transición
/// del estado de auth se traduce en una re-evaluación del redirect.
class AppRouter {
  AppRouter({required AuthBloc authBloc, required AuthRepository repository})
    : _authBloc = authBloc,
      _repo = repository;

  final AuthBloc _authBloc;
  final AuthRepository _repo;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthBlocListenable(_authBloc),
    redirect: _redirect,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(
        path: '/login',
        builder: (context, _) => BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(_repo),
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
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
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
