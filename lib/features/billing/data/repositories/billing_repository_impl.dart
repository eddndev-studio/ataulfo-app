import '../../domain/entities/entitlement.dart';
import '../../domain/repositories/billing_repository.dart';
import '../datasources/billing_datasource.dart';

/// Implementación trivial del puerto: la foto se pide al backend en cada
/// `fetch()` (es estado vivo — el consumo del periodo cambia entre lecturas).
/// Si la UI necesita evitar refetches por pantalla, una capa de caché entra
/// acá sin tocar el contrato del puerto.
class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl({required BillingDatasource datasource})
    : _ds = datasource;

  final BillingDatasource _ds;

  @override
  Future<Entitlement> fetch() => _ds.fetch();
}
