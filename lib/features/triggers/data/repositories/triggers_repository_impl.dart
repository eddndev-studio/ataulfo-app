import '../../domain/entities/trigger.dart';
import '../../domain/repositories/triggers_repository.dart';
import '../datasources/triggers_datasource.dart';

/// Implementación trivial del puerto: el listado no requiere cache local
/// en esta capa. Cuando aterrice RFC-0001 (cache + sync), esta clase
/// orquestará verdad local vs. remota; hoy es delegate.
class TriggersRepositoryImpl implements TriggersRepository {
  TriggersRepositoryImpl({required TriggersDatasource datasource})
    : _ds = datasource;

  final TriggersDatasource _ds;

  @override
  Future<List<Trigger>> listTriggers(String templateId) =>
      _ds.listTriggers(templateId);
}
