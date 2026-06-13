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

  @override
  Future<fdom.Step> createStep({
    required String flowId,
    required fdom.StepType type,
    required int order,
    required String content,
    required String mediaRef,
    required int delayMs,
    required int jitterPct,
    required bool aiOnly,
    bool manualOnly = false,
    String? metadataJson,
  }) => _ds.createStep(
    flowId: flowId,
    type: type,
    order: order,
    content: content,
    mediaRef: mediaRef,
    delayMs: delayMs,
    jitterPct: jitterPct,
    aiOnly: aiOnly,
    manualOnly: manualOnly,
    metadataJson: metadataJson,
  );

  @override
  Future<fdom.Step> patchStep({
    required String stepId,
    String? content,
    String? mediaRef,
    int? delayMs,
    int? jitterPct,
    bool? aiOnly,
    bool? manualOnly,
    int? order,
    String? metadataJson,
  }) => _ds.patchStep(
    stepId: stepId,
    content: content,
    mediaRef: mediaRef,
    delayMs: delayMs,
    jitterPct: jitterPct,
    aiOnly: aiOnly,
    manualOnly: manualOnly,
    order: order,
    metadataJson: metadataJson,
  );

  @override
  Future<void> deleteStep(String stepId) => _ds.deleteStep(stepId);

  @override
  Future<void> reorderSteps({
    required String flowId,
    required List<String> ids,
  }) => _ds.reorderSteps(flowId: flowId, ids: ids);

  @override
  Future<void> deleteFlow(String flowId) => _ds.deleteFlow(flowId);

  @override
  Future<Flow> updateFlow({
    required String flowId,
    required int version,
    required String name,
    required bool isActive,
    required bool aiInvocable,
    required int cooldownMs,
    required int usageLimit,
    required List<String> excludesFlows,
  }) => _ds.updateFlow(
    flowId: flowId,
    version: version,
    name: name,
    isActive: isActive,
    aiInvocable: aiInvocable,
    cooldownMs: cooldownMs,
    usageLimit: usageLimit,
    excludesFlows: excludesFlows,
  );
}
