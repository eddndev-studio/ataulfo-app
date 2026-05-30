import '../entities/chat_profile.dart';

/// Puerto del perfil de un chat. La implementación lanza `ProfileFailure`
/// tipadas; nunca DioException cruda. Hoy refresca contra el backend en cada
/// open (sin cache); cuando aterrice RFC-0001 orquestará local vs. remoto.
abstract interface class ProfileRepository {
  /// `GET /sessions/:botId/:chatLid/profile` org-scoped (el AuthInterceptor
  /// inyecta el Bearer). La foto se consulta en vivo en el backend; puede venir
  /// ausente (contacto sin foto / oculta / wire sin respuesta).
  Future<ChatProfile> fetch(String botId, String chatLid);
}
