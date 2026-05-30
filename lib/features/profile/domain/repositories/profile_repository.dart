import '../entities/chat_profile.dart';

/// Puerto del perfil de un chat. La implementación lanza `ProfileFailure`
/// tipadas; nunca DioException cruda. Refresca contra el backend en cada
/// consulta (sin cache local); la orquestación local vs. remoto la define
/// RFC-0001.
abstract interface class ProfileRepository {
  /// `GET /sessions/:botId/:chatLid/profile` org-scoped (el AuthInterceptor
  /// inyecta el Bearer). La foto se consulta en vivo en el backend; puede venir
  /// ausente (contacto sin foto / oculta / wire sin respuesta).
  Future<ChatProfile> fetch(String botId, String chatLid);
}
