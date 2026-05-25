import '../entities/template.dart';

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
}
