import '../entities/template.dart';
import '../entities/variable_def.dart';

/// Puerto de dominio para Templates (S03). Define los verbos que el bloc
/// puede pedir; las implementaciones viven en `data/`.
abstract interface class TemplatesRepository {
  /// Listado de templates de la org activa. RBAC del backend (CRUD de
  /// Template = ADMIN+) rechaza con 403 si el rol no alcanza.
  Future<List<Template>> list();

  /// Detalle por id; 404 → `TemplatesNotFoundFailure`. Lanza el id es
  /// stale o pertenece a otra org.
  Future<Template> byId(String id);

  /// Crea una Template con el `name` dado. 422 (nombre inválido) →
  /// `TemplatesInvalidNameFailure`. Devuelve la entidad ya persistida con
  /// la AIConfig default que asigna el backend.
  Future<Template> create(String name);

  /// Lista las definiciones de variables de una Template junto con la
  /// `version` vigente del Template padre (CAS para las mutaciones de
  /// var-defs). 404 si la plantilla padre no existe en la org. Lista
  /// vacía es válida.
  Future<({int version, List<VariableDef> defs})> listVarDefs(String id);

  /// Edita la Template (PUT /templates/:id con CAS optimista). 409 ⇒
  /// `TemplatesConflictFailure` (version stale: recargar antes de
  /// reintentar). 422 ⇒ `TemplatesInvalidUpdateFailure`. `ai==null` deja
  /// la config IA intacta.
  Future<Template> update({
    required String id,
    required String name,
    required int version,
    required AIConfig? ai,
  });

  /// Agrega una variable-definition a la Template (POST /templates/:id/
  /// variable-definitions con CAS optimista sobre el Template padre).
  /// Devuelve la def recién creada con su id opaco. 409 (duplicado o
  /// version stale) ⇒ `TemplatesConflictFailure`; 422 (nombre o tipo
  /// inválido) ⇒ `TemplatesInvalidUpdateFailure`; 404 (Template padre)
  /// ⇒ `TemplatesNotFoundFailure`. La nueva version del Template padre
  /// NO viaja en la respuesta — el llamador refetchea el listado.
  Future<VariableDef> addVarDef({
    required String templateId,
    required String name,
    required VarType type,
    required String defaultValue,
    required String description,
    required int version,
  });

  /// Edita una variable-definition (PATCH /variable-definitions/:id con
  /// CAS sobre el Template padre). Sólo los campos provistos se mandan
  /// (only-changed); `null` ⇒ no-op del campo, `''` ⇒ clear explícito.
  /// 409 (rename in-use o stale) ⇒ `TemplatesConflictFailure`; 422 ⇒
  /// `TemplatesInvalidUpdateFailure`; 404 (var-def no existe) ⇒
  /// `TemplatesNotFoundFailure`. El backend devuelve 200 sin body; el
  /// llamador refetchea el listado para refrescar el snapshot.
  Future<void> updateVarDef({
    required String varDefId,
    required int version,
    String? name,
    VarType? type,
    String? defaultValue,
    String? description,
  });

  /// Elimina una variable-definition (DELETE /variable-definitions/:id
  /// con CAS sobre el Template padre). 409 incluye in-use (algún bot
  /// tiene un valor asignado a esta variable — el dominio la trata
  /// como inmutable). 404 si la def no existe. El backend devuelve
  /// 204 sin body.
  Future<void> removeVarDef({required String varDefId, required int version});
}
