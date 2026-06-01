import '../entities/label.dart';

/// Puerto de dominio para Labels internos (S10), org-scoped. En esta capa solo
/// se expone la lectura del catálogo — lo que necesita el selector del mapeo
/// WA↔interno. Lista vacía es válida (la org aún no creó labels).
abstract interface class LabelsRepository {
  Future<List<Label>> listLabels();
}
