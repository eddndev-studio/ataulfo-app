import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_detail_bloc.dart';

/// Hoja de clonado de un Bot (S04). Pide el nombre del clon y despacha sobre el
/// `BotDetailBloc` del scope. El clon es OTRO bot (id nuevo): el éxito no muta
/// el detalle actual sino que NAVEGA al clon — por eso al recibir
/// `CloneSucceeded` cierra el modal y delega la navegación en `onCloned`, que
/// el caller (la página, con su context vivo) ejecuta.
///
/// El orden importa: primero cierra el modal (estamos en su ruta), luego el
/// callback navega desde el context de la página — evita la carrera de pop+push
/// sobre el mismo Navigator que tendrían dos listeners separados.
class BotCloneSheet extends StatefulWidget {
  const BotCloneSheet({super.key, required this.onCloned});

  /// Se invoca con el id del clon tras cerrar el modal. El caller navega.
  final ValueChanged<String> onCloned;

  static void open(
    BuildContext context, {
    required ValueChanged<String> onCloned,
  }) {
    final bloc = context.read<BotDetailBloc>();
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<BotDetailBloc>.value(
        value: bloc,
        child: BotCloneSheet(onCloned: onCloned),
      ),
    );
  }

  @override
  State<BotCloneSheet> createState() => _BotCloneSheetState();
}

class _BotCloneSheetState extends State<BotCloneSheet> {
  static const int _nameMaxLen = 80;

  final TextEditingController _nameCtrl = TextEditingController();
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  bool get _isSubmittable => _nameCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_isSubmittable) return;
    _didSubmit = true;
    context.read<BotDetailBloc>().add(
      BotDetailCloneRequested(_nameCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<BotDetailBloc, BotDetailState>(
      listener: (context, state) {
        if (_didSubmit && state is BotDetailCloneSucceeded) {
          // Cierra el modal y delega la navegación al caller (context vivo).
          Navigator.of(context).pop();
          widget.onCloned(state.newBotId);
        }
      },
      child: BlocBuilder<BotDetailBloc, BotDetailState>(
        builder: (context, state) {
          final isMutating = state is BotDetailMutating;
          final failure = state is BotDetailMutationFailed
              ? state.failure
              : null;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6 + context.sheetBottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Clonar bot', style: textTheme.titleLarge),
                const SizedBox(height: AppTokens.sp2),
                Text(
                  'Se crea un bot nuevo con la misma plantilla y canal, sin '
                  'sesión ni etiquetas. Elige un nombre.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp4),
                AppTextField(
                  key: const Key('bot_clone.name'),
                  label: 'Nombre del clon',
                  hint: 'Soporte (copia)',
                  controller: _nameCtrl,
                  enabled: !isMutating,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_nameMaxLen),
                  ],
                ),
                if (failure != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp3),
                  Text(
                    _failureMessage(failure),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.danger,
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.sp5),
                AppButton.filled(
                  key: const Key('bot_clone.submit'),
                  label: 'Clonar',
                  fullWidth: true,
                  loading: isMutating,
                  onPressed: _isSubmittable ? _submit : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsInvalidCreateFailure() =>
      'El nombre del clon no es válido. Revísalo e inténtalo de nuevo.',
    BotsForbiddenFailure() => 'Tu rol no permite clonar este bot.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsConflictFailure() ||
    BotsNotPausedFailure() ||
    BotsServerFailure() ||
    UnknownBotsFailure() => 'No pudimos clonar el bot. Inténtalo de nuevo.',
  };
}
