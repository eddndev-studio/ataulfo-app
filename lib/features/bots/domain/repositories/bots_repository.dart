import '../entities/bot.dart';

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
  });

  /// Clona un Bot (`POST /bots/:id/clone`). Devuelve el clon con id NUEVO.
  /// `BotsInvalidCreateFailure` (422) si el nombre es inválido;
  /// `BotsNotFoundFailure` (404) si el bot origen no existe.
  Future<Bot> clone({required String id, required String name});
}
