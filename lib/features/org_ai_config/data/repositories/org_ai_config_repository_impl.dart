import '../../domain/entities/org_ai_config.dart';
import '../../domain/repositories/org_ai_config_repository.dart';
import '../datasources/org_ai_config_datasource.dart';

/// Passthrough sobre el datasource. Sin caché: la config de IA de la org se lee
/// por demanda al abrir la pantalla (cabe una caché de sesión aquí después).
class OrgAiConfigRepositoryImpl implements OrgAiConfigRepository {
  const OrgAiConfigRepositoryImpl({required this.datasource});

  final OrgAiConfigDatasource datasource;

  @override
  Future<OrgAiConfig> get() => datasource.get();

  @override
  Future<OrgAiConfig> update(OrgAiConfig config) => datasource.update(config);
}
