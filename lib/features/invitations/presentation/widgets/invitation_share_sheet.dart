import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_wizard_sheet.dart';
import '../../../../core/platform/share_plus_service.dart';
import '../../../../core/platform/share_service.dart';

/// Hoja que muestra —una sola vez, tras emitir— el código de invitación para
/// compartirlo por cualquier canal (WhatsApp). Es la vía de entrega
/// independiente del correo: el ADMIN copia el código o comparte el mensaje
/// completo por el selector de apps del sistema. Honesta sobre si el correo
/// salió; si el backend no devolvió token (versión previa), degrada a sólo el
/// aviso de correo.
class InvitationShareSheet extends StatelessWidget {
  const InvitationShareSheet({
    super.key,
    required this.email,
    required this.token,
    required this.emailSent,
    ShareService? shareService,
    this.onDone,
  }) : _shareService = shareService ?? const SharePlusService();

  final String email;
  final String? token;
  final bool emailSent;
  final ShareService _shareService;
  final VoidCallback? onDone;

  /// Abre la hoja. No devuelve nada: es informativa (compartir el código).
  static Future<void> open(
    BuildContext context, {
    required String email,
    required String? token,
    required bool emailSent,
    ShareService? shareService,
  }) {
    return showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => InvitationShareSheet(
        email: email,
        token: token,
        emailSent: emailSent,
        shareService: shareService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppWizardSheet(
      body: InvitationShareContent(
        email: email,
        token: token,
        emailSent: emailSent,
        shareService: _shareService,
      ),
      footer: InvitationShareDoneAction(onDone: onDone),
    );
  }
}

/// Contenido reutilizable del resultado exitoso de una invitación.
///
/// Separarlo de la superficie permite que el wizard cambie a este estado sin
/// cerrar una hoja y abrir otra, conservando el mismo viewport y el mismo pie.
class InvitationShareContent extends StatelessWidget {
  const InvitationShareContent({
    super.key,
    required this.email,
    required this.token,
    required this.emailSent,
    ShareService? shareService,
  }) : _shareService = shareService ?? const SharePlusService();

  final String email;
  final String? token;
  final bool emailSent;
  final ShareService _shareService;

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
    return Column(
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
            key: const Key('invitation_share.share_message'),
            label: 'Compartir mensaje',
            icon: Icons.share_outlined,
            fullWidth: true,
            onPressed: () => _share(context),
          ),
          const SizedBox(height: AppTokens.sp4),
          Text(
            'Para aceptar, la persona debe iniciar sesión con $email y tener '
            'su correo verificado.',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
        ],
      ],
    );
  }

  void _copy(BuildContext context, String text, String toast) {
    // El aviso sale ya (la copia es instantánea); el write al portapapeles va
    // fire-and-forget para no atar el feedback al ida-y-vuelta de plataforma.
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  void _share(BuildContext context) {
    // El selector del SO ya trae su propio feedback (incluye "copiar" entre
    // las opciones), así que en el camino exitoso no hay SnackBar propio.
    // El messenger se captura ANTES del await: si la plataforma lanza (sin
    // apps/handler que atiendan el intent — p. ej. Linux sin `mailto:`), el
    // mensaje completo deja de ser compartible, así que degrada a copiarlo.
    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      _shareService.shareText(_shareMessage).catchError((Object _) {
        unawaited(Clipboard.setData(ClipboardData(text: _shareMessage)));
        messenger.showSnackBar(
          const SnackBar(content: Text('Invitación copiada')),
        );
      }),
    );
  }
}

/// Acción fija que cierra el resultado exitoso del wizard.
class InvitationShareDoneAction extends StatelessWidget {
  const InvitationShareDoneAction({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return AppButton.filled(
      key: const Key('invitation_share.done'),
      label: 'Listo',
      fullWidth: true,
      onPressed: onDone ?? () => Navigator.of(context).pop(),
    );
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
