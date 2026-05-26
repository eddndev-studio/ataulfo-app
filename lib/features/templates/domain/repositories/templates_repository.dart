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

  /// Lista las definiciones de variables de una Template. 404 si la
  /// plantilla padre no existe en la org. Lista vacía es válida.
  Future<List<VariableDef>> listVarDefs(String id);

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
}
