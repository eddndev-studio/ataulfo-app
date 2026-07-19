import 'package:flutter/material.dart';

import '../../../../core/design/widgets/app_loading_indicator.dart';

/// Splash dumb: el router decide a dónde ir según el estado de auth; aquí
/// solo se ve la marca y el spinner mientras el `AuthBloc` resuelve la
/// primera transición.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Transparente: el glow de fondo (AppBackground) se ve detrás mientras
      // el AuthBloc resuelve la primera transición.
      backgroundColor: Colors.transparent,
      body: AppLoadingIndicator(),
    );
  }
}
