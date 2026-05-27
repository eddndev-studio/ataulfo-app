import '../../domain/entities/flow.dart';
import '../../domain/entities/step.dart' as fdom;
import '../../domain/repositories/flows_repository.dart';
import '../datasources/flows_datasource.dart';

/// Implementación trivial del puerto: el listado no requiere cache local
/// en esta capa. Cuando aterrice RFC-0001 (cache + sync), esta clase
/// orquestará verdad local vs. remota; hoy es delegate.
class FlowsRepositoryImpl implements FlowsRepository {
  FlowsRepositoryImpl({required FlowsDatasource datasource}) : _ds = datasource;

  final FlowsDatasource _ds;

  @override
  Future<List<Flow>> listFlows(String templateId) => _ds.listFlows(templateId);

  @override
  Future<Flow> flowById(String id) => _ds.flowById(id);

  @override
  Future<List<fdom.Step>> listSteps(String flowId) => _ds.listSteps(flowId);

  @override
  Future<Flow> createFlow({required String templateId, required String name}) =>
      _ds.createFlow(templateId: templateId, name: name);
}
