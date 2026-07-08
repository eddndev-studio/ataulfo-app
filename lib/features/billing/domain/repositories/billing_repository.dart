import '../entities/entitlement.dart';

/// Puerto del repositorio del feature billing. La presentación depende de
/// esta interface, no del datasource: si en el futuro el entitlement se
/// cachea por sesión (o se refresca por push), la implementación orquesta
/// verdad local vs. remota sin reabrir el contrato.
abstract interface class BillingRepository {
  /// Devuelve la foto de entitlement vigente de la org activa.
  Future<Entitlement> fetch();
}
