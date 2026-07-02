/// Puerto para compartir texto vía el selector de apps del sistema (OS share
/// sheet): WhatsApp, Telegram, correo, etc. Abstrae la plataforma para que la
/// presentación no dependa del plugin concreto; la implementación real vive
/// en `share_plus_service.dart`.
abstract interface class ShareService {
  /// Abre el selector de apps del sistema con [text] listo para enviar.
  /// [subject] es el asunto opcional que usan las apps que lo soportan
  /// (p. ej. correo); el resto lo ignora.
  Future<void> shareText(String text, {String? subject});
}
