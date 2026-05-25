import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Splash dumb: el router decide a dónde ir según el estado de auth; aquí
/// solo se ve la marca y el spinner mientras el `AuthBloc` resuelve la
/// primera transición.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgBase,
      body: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
        ),
      ),
    );
  }
}
