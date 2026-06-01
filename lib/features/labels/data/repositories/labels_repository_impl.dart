import '../../domain/entities/label.dart';
import '../../domain/repositories/labels_repository.dart';
import '../datasources/labels_datasource.dart';

/// Implementación trivial del puerto: delega en el datasource. Sin cache local
/// en esta capa (cuando aterrice RFC-0001 orquestará verdad local vs. remota).
class LabelsRepositoryImpl implements LabelsRepository {
  LabelsRepositoryImpl({required LabelsDatasource datasource})
    : _ds = datasource;

  final LabelsDatasource _ds;

  @override
  Future<List<Label>> listLabels() => _ds.listLabels();

  @override
  Future<Label> createLabel({
    required String name,
    required String color,
    required String description,
  }) => _ds.createLabel(name: name, color: color, description: description);

  @override
  Future<Label> updateLabel({
    required String id,
    required String name,
    required String color,
    required String description,
  }) => _ds.updateLabel(
    id: id,
    name: name,
    color: color,
    description: description,
  );

  @override
  Future<void> deleteLabel({required String id}) => _ds.deleteLabel(id: id);
}
