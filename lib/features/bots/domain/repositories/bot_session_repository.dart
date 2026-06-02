import '../entities/connect_link.dart';

/// Puerto de dominio para el emparejamiento de un Bot (S04): control de la
/// sesión de canal y emisión del enlace público a compartir. Define los
/// verbos que el bloc puede pedir; las implementaciones viven en `data/`.
///
/// Las implementaciones lanzan `BotsFailure` (misma jerarquía sellada del
/// feature); el bloc las traduce a estados de UI.
abstract interface class BotSessionRepository {
  /// Arranca la sesión de canal del bot (→ PAIRING): el backend genera el QR.
  Future<void> startSession(String botId);

  /// Detiene la sesión (idempotente). Usado al cancelar el emparejamiento.
  Future<void> stopSession(String botId);

  /// Emite un ConnectToken y devuelve el enlace público a compartir con
  /// quien escaneará el QR desde la página `/connect`.
  Future<ConnectLink> issueConnectLink(String botId);

  /// Purga conversaciones del bot (`clear-conversations`). EXIGE `paused`:
  /// `BotsNotPausedFailure` (409) si no lo está.
  Future<void> clearConversations(String botId);

  /// Reinicia las sesiones de cifrado (`reset-sessions`). EXIGE `paused`:
  /// `BotsNotPausedFailure` (409) si no lo está.
  Future<void> resetSessions(String botId);
}
