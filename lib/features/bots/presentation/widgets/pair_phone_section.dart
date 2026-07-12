import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_connect_bloc.dart';
import '../pair_phone_form.dart';

/// Sección «vincular con código» (pair-phone), la vía alterna al QR. La page
/// la monta SOLO en el branch que muestra el QR (sesión PAIRING): el backend
/// únicamente emite códigos ahí, y ambos comparten la misma ventana de vida.
///
/// Captura el teléfono (validación local espejo de whatsmeow, error en sitio
/// sin tocar el bloc) y pinta el código TAL CUAL llega del wire (`XXXX-XXXX`,
/// ya formateado). Pedir otro código sigue disponible: cada pedida invalida
/// la anterior.
class PairPhoneSection extends StatefulWidget {
  const PairPhoneSection({
    super.key,
    required this.pairCode,
    required this.pairRequesting,
    required this.pairFailure,
  });

  final String? pairCode;
  final bool pairRequesting;
  final BotsFailure? pairFailure;

  @override
  State<PairPhoneSection> createState() => _PairPhoneSectionState();
}

class _PairPhoneSectionState extends State<PairPhoneSection> {
  final TextEditingController _phone = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  /// Valida local primero (error en sitio, sin tocar el bloc); lo que viaja
  /// al wire es SIEMPRE el saneado. El guard de re-entrada vive en el bloc y
  /// el loading del botón bloquea el doble-tap.
  void _submit() {
    final error = validaTelefono(_phone.text);
    setState(() => _localError = error);
    if (error != null) return;
    context.read<BotConnectBloc>().add(
      BotConnectPairCodeRequested(saneaTelefono(_phone.text)),
    );
  }

  Future<void> _copyCode(String code) async {
    // Capturado antes del await: mismo patrón clipboard que el enlace.
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  /// El error local (validación) gana sobre el del wire: es más específico y
  /// el operador lo acaba de provocar tecleando.
  String? get _errorText {
    final local = _localError;
    if (local != null) return local;
    final failure = widget.pairFailure;
    return failure == null ? null : _failureCopy(failure);
  }

  static String _failureCopy(BotsFailure f) => switch (f) {
    BotsPairingNotStartedFailure() => 'Primero inicia el emparejamiento.',
    BotsPhoneRejectedFailure() =>
      'Número no aceptado. Usa formato internacional sin “+” '
          '(p. ej. 5215512345678).',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e intenta de nuevo.',
    _ => 'No pudimos generar el código. Inténtalo de nuevo.',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final code = widget.pairCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(color: AppTokens.divider, height: 1),
        const SizedBox(height: AppTokens.sp4),
        Text('O vincula con un código', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.sp2),
        Text(
          'Escribe el número del teléfono que quieres vincular. Recibirá una '
          'notificación de WhatsApp.',
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp4),
        AppTextField(
          key: const Key('bot_connect.pair_phone'),
          label: 'Número de teléfono',
          hint: '5215512345678',
          controller: _phone,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          autocorrect: false,
          errorText: _errorText,
        ),
        const SizedBox(height: AppTokens.sp3),
        AppButton.tonal(
          key: const Key('bot_connect.pair_submit'),
          label: 'Generar código',
          fullWidth: true,
          loading: widget.pairRequesting,
          onPressed: _submit,
        ),
        if (code != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp4),
          AppCard(
            child: SelectableText(
              // Llega YA formateado (XXXX-XXXX): tal cual, sin re-agrupar ni
              // validar largo.
              code,
              key: const Key('bot_connect.pair_code'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppTokens.text1,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'En WhatsApp: Dispositivos vinculados › Vincular con el número de '
            'teléfono. Válido ~2 minutos.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp3),
          AppButton.tonal(
            label: 'Copiar código',
            fullWidth: true,
            onPressed: () => _copyCode(code),
          ),
        ],
      ],
    );
  }
}
