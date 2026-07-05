import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/tokens.dart';
import '../design/widgets/app_top_banner.dart';
import 'connectivity_cubit.dart';

/// Envuelve la app y, cuando no hay conexión, muestra una barra delgada arriba
/// que empuja el contenido hacia abajo. En offline-first estar sin red es un
/// estado NORMAL (los cambios se encolan y sincronizan al reconectar), así que
/// el tono es discreto, no de error.
///
/// La coordinación con el status bar (consumir el inset y retirárselo al
/// contenido mientras la barra está visible) la aporta [AppTopBanner].
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<ConnectivityCubit, bool>(
      builder: (context, online) => AppTopBanner(
        visible: !online,
        bannerKey: const Key('connectivity_banner.offline'),
        content: Row(
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
                style: textTheme.labelMedium?.copyWith(color: AppTokens.text1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
