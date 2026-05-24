import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Widget raíz. Recibe el router y el AuthBloc ya construidos (composición
/// desde main) — testeable sin inicializar plataforma.
///
/// El AuthBloc se provee globalmente para que cualquier feature (logout
/// desde un menú, indicador de sesión en la app bar, etc.) lo lea sin
/// depender del router.
class AgenticApp extends StatelessWidget {
  const AgenticApp({super.key, required this.router, required this.authBloc});

  final AppRouter router;
  final AuthBloc authBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(
        title: 'Agentic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: router.router,
      ),
    );
  }
}
