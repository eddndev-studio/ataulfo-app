import '../entities/template.dart';

/// Puerto de dominio para Templates (S03). Define los verbos que el bloc
/// puede pedir; las implementaciones viven en `data/`.
abstract interface class TemplatesRepository {
  /// Listado de templates de la org activa. RBAC del backend (CRUD de
  /// Template = ADMIN+) rechaza con 403 si el rol no alcanza.
  Future<List<Template>> list();
}
