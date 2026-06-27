import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/tokens.dart';
import 'connectivity_cubit.dart';

/// Envuelve la app y, cuando no hay conexión, muestra una barra delgada arriba
/// que empuja el contenido hacia abajo. En offline-first estar sin red es un
/// estado NORMAL (los cambios se encolan y sincronizan al reconectar), así que
/// el tono es discreto, no de error.
///
/// Cuando la barra aparece consume el inset del status bar (su `SafeArea`); el
/// contenido de abajo pierde su padding superior para no duplicarlo.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, bool>(
      builder: (context, online) => Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: online
                ? const SizedBox(
                    key: ValueKey('online'),
                    width: double.infinity,
                  )
                : const _OfflineBar(key: ValueKey('offline')),
          ),
          Expanded(
            child: online
                ? child
                // La barra ya cubrió el status bar: evita el doble padding.
                : MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: const Key('connectivity_banner.offline'),
      color: AppTokens.surface2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp3,
            vertical: AppTokens.sp2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 16,
                color: AppTokens.warning,
              ),
              const SizedBox(width: AppTokens.sp2),
              Flexible(
                child: Text(
                  'Sin conexión · los cambios se sincronizan al reconectar',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppTokens.text1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
