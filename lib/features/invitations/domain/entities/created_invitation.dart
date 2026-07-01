/// Resultado de emitir una invitación. Además de existir en el historial, la
/// creación devuelve —sólo esta vez— el [token] crudo para que el ADMIN comparta
/// la invitación por cualquier canal (WhatsApp), y [emailSent] para ser honesto
/// sobre si el correo salió. El token NUNCA vuelve a viajar: si no se comparte
/// ahora, hay que cancelar y reinvitar para obtener uno nuevo.
class CreatedInvitation {
  const CreatedInvitation({
    required this.email,
    required this.token,
    required this.emailSent,
  });

  /// Correo invitado (para armar el mensaje compartible y el aviso).
  final String email;

  /// Token crudo a compartir. Nulo si un backend previo no lo devuelve (el
  /// flujo degrada a "revisa el correo" sin código copiable).
  final String? token;

  /// Si el backend logró enviar el correo de invitación.
  final bool emailSent;
}
