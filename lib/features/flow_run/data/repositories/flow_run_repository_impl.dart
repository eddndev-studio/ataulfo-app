import '../../domain/entities/runnable_flow.dart';
import '../../domain/repositories/flow_run_repository.dart';
import '../datasources/flow_run_datasource.dart';

/// Implementación trivial del puerto: delega al datasource HTTP. Sin cache.
class FlowRunRepositoryImpl implements FlowRunRepository {
  FlowRunRepositoryImpl(this._ds);

  final FlowRunDatasource _ds;

  @override
  Future<List<RunnableFlow>> listRunnable(String botId) =>
      _ds.listRunnable(botId);

  @override
  Future<String> run({
    required String botId,
    required String chatLid,
    required String flowId,
  }) => _ds.run(botId: botId, chatLid: chatLid, flowId: flowId);
}
