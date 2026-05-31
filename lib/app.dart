import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/design/app_design_theme.dart';
import 'core/design/widgets/app_background.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

/// Widget raíz. Recibe el router y el AuthBloc ya construidos (composición
/// desde main) — testeable sin inicializar plataforma.
///
/// El AuthBloc se provee globalmente para que cualquier feature (logout
/// desde un menú, indicador de sesión en la app bar, etc.) lo lea sin
/// depender del router.
///
/// Tema dark-only: el producto no expone modo claro. `theme` actúa como
/// el ThemeData universal porque `darkTheme` queda en null y MaterialApp
/// usa `theme` como fallback cuando no hay variante dark separada.
class AtaulfoApp extends StatelessWidget {
  const AtaulfoApp({
    super.key,
    required this.router,
    required this.authBloc,
    required this.onSignedOut,
  });

  final AppRouter router;
  final AuthBloc authBloc;

  /// Se invoca cuando la sesión cae a [AuthUnauthenticated] (logout explícito o
  /// purga por refresh agotado). La composición lo enchufa a la limpieza de
  /// caches de sesión (p. ej. `MediaRepository.invalidate`) para no arrastrar
  /// la verdad local de una cuenta a la siguiente sin reiniciar la app.
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) => current is AuthUnauthenticated,
        listener: (_, _) => onSignedOut(),
        child: MaterialApp.router(
          title: 'Ataúlfo',
          debugShowCheckedModeBanner: false,
          theme: AppDesignTheme.dark(),
          routerConfig: router.router,
          // El glow radial es el fondo absoluto de la app: se pinta una sola
          // vez detrás del navigator y queda fijo mientras las rutas (con
          // scaffolds transparentes) transicionan encima.
          builder: (context, child) =>
              AppBackground(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
