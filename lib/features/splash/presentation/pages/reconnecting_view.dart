import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/network/connectivity_cubit.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Vista de arranque cuando hay una sesión persistida pero no se pudo verificar
/// contra el servidor por falta de red. A diferencia del login, deja claro que
/// la sesión NO se perdió: solo se espera a la conexión.
///
/// Reintenta la verificación por tres vías complementarias, porque "sin red"
/// abarca más que un enlace caído:
///  - el flanco enlace-ausente→enlace-presente, para recuperar al instante
///    cuando vuelve el wifi/datos;
///  - un sondeo periódico, porque el fallo también ocurre con el enlace ARRIBA
///    pero el servidor inalcanzable (portal cautivo, datos débiles, backend
///    reiniciando), caso en el que el enlace nunca cambia y el flanco no llega;
///  - un reintento manual.
/// Al primer éxito el `AuthBloc` flipa a autenticado y el router entra al home.
class ReconnectingView extends StatefulWidget {
  const ReconnectingView({super.key});

  @override
  State<ReconnectingView> createState() => _ReconnectingViewState();
}

class _ReconnectingViewState extends State<ReconnectingView> {
  /// Cadencia del sondeo. La verificación es barata (sin red, Dio falla de
  /// inmediato; con el enlace arriba es un solo GET ligero), y la vista solo
  /// vive mientras la sesión está sin verificar, así que el costo es acotado.
  static const Duration _pollInterval = Duration(seconds: 5);

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_pollInterval, (_) => _retry());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _retry() {
    if (!mounted) return;
    context.read<AuthBloc>().add(const AuthCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<ConnectivityCubit, bool>(
      // Solo el flanco offline→online reintenta al instante: una caída de red
      // no debe disparar verificaciones, y un online sostenido lo cubre el
      // sondeo periódico, no este listener.
      listenWhen: (previous, current) => !previous && current,
      listener: (context, _) => _retry(),
      child: Scaffold(
        // Transparente: deja ver el glow de fondo, igual que el Splash.
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppTokens.warning,
                ),
                const SizedBox(height: AppTokens.sp3),
                Text(
                  'Sin conexión',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppTokens.text1,
                  ),
                ),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  'Tu sesión sigue activa. Reconectaremos en cuanto vuelva la red.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp4),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
                ),
                const SizedBox(height: AppTokens.sp4),
                TextButton(
                  onPressed: _retry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
