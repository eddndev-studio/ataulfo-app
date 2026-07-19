import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_detail_bloc.dart';

/// Hoja de edición de un Bot (S04). Sólo el `name` es editable: el canal es
/// inmutable (I-B3) y el `identifier` es create-only — ambos se muestran
/// read-only. Despacha sobre el `BotDetailBloc` del scope y refleja el
/// resultado: loading mientras el PUT está en vuelo, copy de error si falla,
/// cierre automático al éxito.
///
/// Un modal vive en otro subárbol del Navigator, así que `openEdit` re-provee
/// el bloc del scope a la hoja con `BlocProvider.value` (mismo patrón que
/// `LabelEditSheet`).
class BotEditSheet extends StatefulWidget {
  const BotEditSheet({super.key, required this.bot});

  final Bot bot;

  static void openEdit(BuildContext context, Bot bot) {
    final bloc = context.read<BotDetailBloc>();
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => BlocProvider<BotDetailBloc>.value(
        value: bloc,
        child: BotEditSheet(bot: bot),
      ),
    );
  }

  @override
  State<BotEditSheet> createState() => _BotEditSheetState();
}

class _BotEditSheetState extends State<BotEditSheet> {
  static const int _nameMaxLen = 80;

  late final TextEditingController _nameCtrl;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.bot.name);
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
      BotDetailUpdateRequested(name: _nameCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<BotDetailBloc, BotDetailState>(
      listener: (context, state) {
        // Tras una mutación propia exitosa el bloc vuelve a Loaded: cierra.
        if (_didSubmit && state is BotDetailLoaded) {
          Navigator.of(context).maybePop();
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
                Text('Editar Canal', style: textTheme.titleLarge),
                const SizedBox(height: AppTokens.sp4),
                AppTextField(
                  key: const Key('bot_edit.name'),
                  label: 'Nombre',
                  hint: 'Nombre del Canal',
                  controller: _nameCtrl,
                  enabled: !isMutating,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_nameMaxLen),
                  ],
                ),
                const SizedBox(height: AppTokens.sp4),
                Text(
                  'Canal',
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: AppTokens.sp2),
                // El canal se fija al crear el bot y no se puede cambiar
                // (cambiarlo exige un bot nuevo). Read-only como pill.
                AppPill.outline(label: _channelLabel(widget.bot.channel)),
                if (widget.bot.identifier != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp4),
                  Text(
                    'Identificador',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp1),
                  SelectableText(
                    widget.bot.identifier!,
                    style: textTheme.bodyMedium,
                  ),
                ],
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
                  key: const Key('bot_edit.submit'),
                  label: 'Guardar',
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

  static String _channelLabel(BotChannel c) => switch (c) {
    BotChannel.waUnofficial => 'WhatsApp',
    BotChannel.waba => 'WhatsApp Business',
  };

  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsConflictFailure() =>
      'Tu edición estaba desactualizada; la refrescamos. Revisa y reintenta.',
    BotsInvalidCreateFailure() =>
      'El nombre no es válido. Revísalo e inténtalo de nuevo.',
    BotsForbiddenFailure() => 'Tu rol no permite editar este Canal.',
    BotsNotFoundFailure() => 'Este Canal ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsNotPausedFailure() ||
    BotsPairingNotStartedFailure() ||
    BotsPhoneRejectedFailure() ||
    BotsServerFailure() ||
    UnknownBotsFailure() => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}
