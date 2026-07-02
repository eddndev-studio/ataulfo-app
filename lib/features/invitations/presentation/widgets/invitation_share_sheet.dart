import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';

/// Hoja que muestra —una sola vez, tras emitir— el código de invitación para
/// compartirlo por cualquier canal (WhatsApp). Es la vía de entrega
/// independiente del correo: el ADMIN copia el código o el mensaje completo y
/// se lo pasa a la persona. Honesta sobre si el correo salió; si el backend no
/// devolvió token (versión previa), degrada a sólo el aviso de correo.
class InvitationShareSheet extends StatelessWidget {
  const InvitationShareSheet({
    super.key,
    required this.email,
    required this.token,
    required this.emailSent,
  });

  final String email;
  final String? token;
  final bool emailSent;

  /// Abre la hoja. No devuelve nada: es informativa (compartir el código).
  static Future<void> open(
    BuildContext context, {
    required String email,
    required String? token,
    required bool emailSent,
  }) {
    return showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => InvitationShareSheet(
        email: email,
        token: token,
        emailSent: emailSent,
      ),
    );
  }

  /// Mensaje listo para pegar en WhatsApp: instrucciones + código. Los pasos
  /// siguen el flujo real de aceptación (verificar el correo es obligatorio, y
  /// la invitación aparece sola en "Tus organizaciones" una vez verificado).
  String get _shareMessage =>
      '🥭 Te invitaron a colaborar en una organización en Ataúlfo.\n\n'
      'Para unirte:\n'
      '1. Descarga Ataúlfo\n'
      '2. Crea tu cuenta con este correo: $email\n'
      '3. Verifica tu correo con el código que te llegue\n'
      '4. Tu invitación aparecerá en Ajustes → Tus organizaciones (toca '
      '"Unirse"). También puedes ingresar este código en Ajustes → Unirse a '
      'una organización:\n\n'
      '${token ?? ''}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final code = token;
    // El aviso se ancla en la PRESENCIA del código, no sólo en si el correo
    // salió: sin código a la mano (un backend previo que no lo devolvió) no
    // prometemos compartir un código que no está en pantalla.
    final String message;
    if (code != null) {
      message = emailSent
          ? 'Le enviamos un correo a $email. Si no le llega, comparte el '
                'código directo (por WhatsApp, por ejemplo).'
          : 'No pudimos enviar el correo a $email. Comparte este código '
                'para que se una:';
    } else {
      message = emailSent
          ? 'Le enviamos un correo a $email para que se una.'
          : 'No pudimos enviar el correo a $email. Cancela la invitación y '
                'vuelve a enviarla para reintentar.';
    }
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
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                color: AppTokens.success,
                size: 24,
              ),
              const SizedBox(width: AppTokens.sp2),
              Expanded(
                child: Text('Invitación creada', style: textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp3),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: emailSent ? AppTokens.text2 : AppTokens.warning,
            ),
          ),
          if (code != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _CodeBox(code: code),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: const Key('invitation_share.copy_code'),
              label: 'Copiar código',
              icon: Icons.content_copy,
              fullWidth: true,
              onPressed: () => _copy(context, code, 'Código copiado'),
            ),
            const SizedBox(height: AppTokens.sp2),
            AppButton.tonal(
              key: const Key('invitation_share.copy_message'),
              label: 'Copiar mensaje',
              icon: Icons.share_outlined,
              fullWidth: true,
              onPressed: () =>
                  _copy(context, _shareMessage, 'Invitación copiada'),
            ),
            const SizedBox(height: AppTokens.sp4),
            Text(
              'Para aceptar, la persona debe iniciar sesión con $email y tener '
              'su correo verificado.',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
          ],
          const SizedBox(height: AppTokens.sp4),
          AppButton.text(
            label: 'Listo',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String toast) {
    // El aviso sale ya (la copia es instantánea); el write al portapapeles va
    // fire-and-forget para no atar el feedback al ida-y-vuelta de plataforma.
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }
}

/// Caja monoespaciada con el código, seleccionable, para leerlo o copiarlo a
/// mano si el botón no basta.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp4,
        vertical: AppTokens.sp3,
      ),
      decoration: BoxDecoration(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.divider),
      ),
      child: SelectableText(
        code,
        key: const Key('invitation_share.code'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: AppTokens.text1,
        ),
      ),
    );
  }
}
