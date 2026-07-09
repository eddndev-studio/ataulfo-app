import '../../domain/entities/composition_job.dart';
import '../../domain/repositories/composition_repository.dart';
import '../datasources/composition_datasource.dart';

/// Delega en el datasource: los jobs son estado vivo del backend (avanzan
/// solos de QUEUED a DONE) y cachearlos mentiría; el poll del cubit es la
/// fuente de frescura.
class CompositionRepositoryImpl implements CompositionRepository {
  CompositionRepositoryImpl({required CompositionDatasource datasource})
    : _ds = datasource;

  final CompositionDatasource _ds;

  @override
  Future<String> compose({
    required String productId,
    required String preset,
    bool premium = false,
  }) => _ds.compose(productId: productId, preset: preset, premium: premium);

  @override
  Future<List<CompositionJob>> listJobs(String productId) =>
      _ds.listJobs(productId);

  @override
  Future<void> accept(String jobId) => _ds.accept(jobId);

  @override
  Future<void> discard(String jobId) => _ds.discard(jobId);
}
