import '../entities/bot.dart';
import '../entities/bot_variables_snapshot.dart';

/// Puerto de dominio para Bots (S04). Define los verbos que el bloc puede
/// pedir; las implementaciones viven en `data/`.
abstract interface class BotsRepository {
  /// Listado de bots de la org activa. RBAC del backend filtra por rol:
  /// SUPERVISOR+ ven todos; WORKER solo los asignados a su Membership.
  Future<List<Bot>> list();

  /// Detalle de un bot por ID. Lanza `BotsNotFoundFailure` si el ID no
  /// existe en la org activa (404), `BotsForbiddenFailure` si el rol no
  /// alcanza (403), o las variantes de red/timeout/server si el transporte
  /// falla. El bloc traduce a estado de UI.
  Future<Bot> byId(String id);

  /// Crea un Bot ligado a una Template existente de la org activa.
  /// `BotsInvalidCreateFailure` (422) cuando el backend rechaza la
  /// construcción; el bloc decide cómo mostrarlo al operador.
  Future<Bot> create({
    required String templateId,
    required String name,
    required BotChannel channel,
    String? identifier,
  });

  /// Edita un Bot existente (`PUT /bots/:id` con CAS optimista por `version`).
  /// Cuerpo tristate: los campos null se omiten ("no tocar"). Devuelve el Bot
  /// actualizado (con `version+1`). `BotsConflictFailure` (409) cuando la
  /// `version` quedó atrás; `BotsInvalidCreateFailure` (422) si el dominio
  /// rechaza el cambio; `BotsNotFoundFailure` (404) si el bot no existe. El
  /// canal e `identifier` NO se editan (inmutables / create-only).
  Future<Bot> update({
    required String id,
    required int version,
    String? name,
    bool? paused,
    bool? aiDisabled,
    Map<String, String>? variableValues,
    List<String>? disabledToolGroups,
  });

  /// Lee los `variable_values` guardados de un Bot para el editor
  /// (`GET /bots/:id/variables`, ADMIN+), junto con la `version` (CAS) y el
  /// `templateId` (para resolver las definiciones). `BotsForbiddenFailure`
  /// (403) si el rol no alcanza; `BotsNotFoundFailure` (404) si el bot no
  /// existe en la org.
  Future<BotVariablesSnapshot> getVariables(String id);

  /// Clona un Bot (`POST /bots/:id/clone`). Devuelve el clon con id NUEVO.
  /// `BotsInvalidCreateFailure` (422) si el nombre es inválido;
  /// `BotsNotFoundFailure` (404) si el bot origen no existe.
  Future<Bot> clone({required String id, required String name});

  /// Borra un Bot (`DELETE /bots/:id`). `BotsNotFoundFailure` (404) si ya no
  /// existe. Deja huérfanas las tablas de runtime sin FK (la UI lo advierte).
  Future<void> delete(String id);
}
