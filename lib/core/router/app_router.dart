import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/token_storage.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';

/// Rutas de la app. `/` es decisión: si hay tokens persistidos, va a
/// `/home`; si no, a `/login`. Esa decisión vive en `_RootRedirect` para
/// que el splash sea trivial.
///
/// `LoginBloc` se monta scope-de-página por `BlocProvider`. Es legítimo
/// para un bloc per-route (vida igual a la ruta). Los blocs compartidos
/// (auth, push, etc.) suben al `app.dart` cuando aterricen.
class AppRouter {
  AppRouter({
    required AuthDatasource authDatasource,
    required TokenStorage tokenStorage,
  }) : _ds = authDatasource,
       _storage = tokenStorage;

  final AuthDatasource _ds;
  final TokenStorage _storage;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => _Splash(storage: _storage),
      ),
      GoRoute(
        path: '/login',
        builder: (context, _) => BlocProvider<LoginBloc>(
          create: (_) =>
              LoginBloc(AuthRepositoryImpl(datasource: _ds, storage: _storage)),
          child: LoginPage(onSucceeded: (_) => context.go('/home')),
        ),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
    ],
  );
}

/// Splash mínimo: lee storage, decide ruta. Sin animación — un slice de
/// branding lo decora si producto lo pide.
class _Splash extends StatefulWidget {
  const _Splash({required this.storage});

  final TokenStorage storage;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final tokens = await widget.storage.read();
    if (!mounted) return;
    context.go(tokens == null ? '/login' : '/home');
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
