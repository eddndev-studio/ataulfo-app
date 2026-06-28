import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/design/app_design_theme.dart';
import 'core/design/widgets/app_background.dart';
import 'core/design/widgets/app_content_width.dart';
import 'core/network/connectivity_banner.dart';
import 'core/network/connectivity_cubit.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/messages/data/cache/message_media_cache.dart';
import 'features/profile/data/cache/profile_photo_cache.dart';

/// True cuando la organización ACTIVA cambió entre dos estados autenticados
/// (mismo usuario, otra org), como tras un cambio de organización. Es la
/// frontera que dispara la purga de la verdad local reconstruible: la del
/// servidor de la org anterior no debe verse en la nueva. No incluye
/// login/logout ni la transición a/desde "sin org activa": sólo org→otra-org.
bool isActiveOrgChange(AuthState previous, AuthState current) =>
    previous is AuthAuthenticated &&
    current is AuthAuthenticated &&
    previous.identity.orgId != current.identity.orgId;

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
    required this.connectivityCubit,
    required this.profilePhotoCache,
    required this.messageMediaCache,
    required this.onSignedOut,
    required this.onOrgChanged,
  });

  final AppRouter router;
  final AuthBloc authBloc;

  /// Caché de fotos de perfil (L1 memoria + L2 disco) provista globalmente para
  /// que cualquier avatar de la app (bandeja, header del hilo) la lea sin
  /// pasarla por las rutas. Account-scoped: se purga en `onSignedOut`.
  final ProfilePhotoCache profilePhotoCache;

  /// Caché de bytes de la media de los mensajes (imagen/sticker del hilo)
  /// provista globalmente; sirve offline por `mediaRef`. Su memoria se purga en
  /// `onSignedOut` (los bytes en disco son inmutables y org-safe).
  final MessageMediaCache messageMediaCache;

  /// Señal de conectividad global (online/offline) que la UI (banner) y los
  /// consumidores leen sin depender del router.
  final ConnectivityCubit connectivityCubit;

  /// Se invoca cuando la sesión cae a [AuthUnauthenticated] (logout explícito o
  /// purga por refresh agotado). La composición lo enchufa a la limpieza de
  /// caches de sesión (p. ej. `MediaRepository.invalidate`) para no arrastrar
  /// la verdad local de una cuenta a la siguiente sin reiniciar la app.
  final VoidCallback onSignedOut;

  /// Se invoca al cambiar de organización activa (mismo usuario, otra org). La
  /// composición lo enchufa a la purga de la verdad local RECONSTRUIBLE y de las
  /// cachés de sesión, conservando el outbox, para no mostrar datos de la org
  /// anterior en la nueva.
  final VoidCallback onOrgChanged;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProfilePhotoCache>.value(value: profilePhotoCache),
        RepositoryProvider<MessageMediaCache>.value(value: messageMediaCache),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          // Dos fronteras de sesión: el logout purga TODO; el cambio de org
          // activa purga sólo la verdad reconstruible (conserva el outbox).
          listenWhen: (previous, current) =>
              current is AuthUnauthenticated ||
              isActiveOrgChange(previous, current),
          listener: (_, state) {
            if (state is AuthUnauthenticated) {
              onSignedOut();
            } else {
              onOrgChanged();
            }
          },
          child: MaterialApp.router(
            title: 'Ataúlfo',
            debugShowCheckedModeBanner: false,
            theme: AppDesignTheme.dark(),
            routerConfig: router.router,
            // El glow radial es el fondo absoluto de la app: se pinta una sola
            // vez detrás del navigator y queda fijo mientras las rutas (con
            // scaffolds transparentes) transicionan encima. El contenido se
            // restringe al ancho máximo (centrado en desktop) POR DENTRO del
            // glow, para que el fondo llene los costados libres.
            builder: (context, child) => AppBackground(
              child: AppContentWidth(
                child: ConnectivityBanner(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
