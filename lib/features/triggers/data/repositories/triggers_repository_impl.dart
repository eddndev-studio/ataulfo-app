// ignore_for_file: avoid_positional_boolean_parameters

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

  @override
  Future<Trigger> createTrigger({
    required String templateId,
    required String flowId,
    required TriggerType triggerType,
    required MatchType? matchType,
    required String keyword,
    required String labelId,
    required LabelAction? labelAction,
    required TriggerScope scope,
    required bool isActive,
  }) => _ds.createTrigger(
    templateId: templateId,
    flowId: flowId,
    triggerType: triggerType,
    matchType: matchType,
    keyword: keyword,
    labelId: labelId,
    labelAction: labelAction,
    scope: scope,
    isActive: isActive,
  );

  @override
  Future<Trigger> updateTrigger({
    required String triggerId,
    required TriggerType triggerType,
    required MatchType? matchType,
    required String keyword,
    required String labelId,
    required LabelAction? labelAction,
    required TriggerScope scope,
    required bool isActive,
  }) => _ds.updateTrigger(
    triggerId: triggerId,
    triggerType: triggerType,
    matchType: matchType,
    keyword: keyword,
    labelId: labelId,
    labelAction: labelAction,
    scope: scope,
    isActive: isActive,
  );

  @override
  Future<void> deleteTrigger(String triggerId) => _ds.deleteTrigger(triggerId);
}
