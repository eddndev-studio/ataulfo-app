import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../../../core/prefs/motion_settings_cubit.dart';

/// Apariencia: preferencias visuales del dispositivo (no de la cuenta).
///
/// Content-only — el router monta el Scaffold+AppBar('Apariencia'). Hoy una
/// sola preferencia: las animaciones de la interfaz (opt-out, apply-inmediato
/// como todo toggle del producto). La preferencia vive en
/// [MotionSettingsCubit] (global): apagar aquí congela micro-animaciones y
/// transiciones en toda la app al instante.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCard(
            child: BlocBuilder<MotionSettingsCubit, bool>(
              builder: (context, enabled) => AppToggleRow(
                switchKey: const Key('appearance.animations'),
                label: 'Animaciones',
                caption:
                    'Íconos, botones y transiciones con movimiento suave. '
                    'Si tu sistema pide reducir movimiento, se respeta '
                    'aunque estén encendidas.',
                value: enabled,
                onChanged: (value) =>
                    context.read<MotionSettingsCubit>().setEnabled(value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
