import '../../domain/entities/org_branding.dart';
import '../../domain/repositories/org_branding_repository.dart';
import '../datasources/org_branding_datasource.dart';

/// Impl directa sobre el datasource: el módulo es online-only (config de la
/// org), sin caché local que reconciliar.
class OrgBrandingRepositoryImpl implements OrgBrandingRepository {
  const OrgBrandingRepositoryImpl({required OrgBrandingDatasource datasource})
    : _datasource = datasource;

  final OrgBrandingDatasource _datasource;

  @override
  Future<OrgBranding> get() => _datasource.get();

  @override
  Future<void> setLogo(String mediaRef) => _datasource.setLogo(mediaRef);

  @override
  Future<void> reset() => _datasource.reset();
}
