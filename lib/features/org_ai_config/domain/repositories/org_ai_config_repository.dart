import '../entities/org_ai_config.dart';

/// Puerto de la config de IA de la org. Las impls lanzan `OrgAiConfigFailure`
/// (sellada) ante fallo; nunca devuelven null.
abstract interface class OrgAiConfigRepository {
  /// Lee la config de IA de la org activa (del claim).
  Future<OrgAiConfig> get();

  /// Reemplaza la config de IA de la org y devuelve la guardada.
  Future<OrgAiConfig> update(OrgAiConfig config);
}
