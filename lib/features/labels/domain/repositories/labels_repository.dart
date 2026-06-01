import '../entities/label.dart';

/// Puerto de dominio del catálogo de Labels internos (S10), org-scoped. Expone
/// la lectura (que puebla el selector de disparadores y el mapeo WA↔interno) y
/// el CRUD que gestiona la sección de etiquetas. Lista vacía es válida (la org
/// aún no creó labels).
///
/// Los consumidores de solo lectura (selectores) usan únicamente `listLabels`;
/// la pantalla de gestión usa además create/update/delete.
abstract interface class LabelsRepository {
  Future<List<Label>> listLabels();

  Future<Label> createLabel({
    required String name,
    required String color,
    required String description,
  });

  Future<Label> updateLabel({
    required String id,
    required String name,
    required String color,
    required String description,
  });

  Future<void> deleteLabel({required String id});
}
