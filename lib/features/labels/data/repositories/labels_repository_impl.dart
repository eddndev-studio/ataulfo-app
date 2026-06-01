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
}
