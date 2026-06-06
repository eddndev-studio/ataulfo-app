import '../../domain/entities/quick_reply.dart';
import '../../domain/repositories/quick_replies_repository.dart';
import '../datasources/quick_replies_catalog_datasource.dart';

/// Implementación del puerto de catálogo de respuestas rápidas WhatsApp (S23).
/// Delega en el datasource del catálogo y mantiene un espejo en memoria por bot
/// para la lectura síncrona `cachedCatalog`: como el repo es singleton de
/// sesión, reabrir un hilo siembra el selector ⚡ al instante en vez de mostrar
/// "cargando" mientras una nueva consulta viaja a la red.
class QuickRepliesRepositoryImpl implements QuickRepliesRepository {
  QuickRepliesRepositoryImpl({required QuickRepliesCatalogDatasource catalog})
    : _catalog = catalog;

  final QuickRepliesCatalogDatasource _catalog;

  /// Espejo del último catálogo por bot, de vida de sesión. Su único fin es la
  /// lectura síncrona `cachedCatalog`; `listCatalog` SIEMPRE revalida contra el
  /// server (stale-while-revalidate) y refresca esta entrada. Un fallo de
  /// revalidación NO toca la entrada previa.
  final Map<String, List<QuickReply>> _cache = <String, List<QuickReply>>{};

  @override
  Future<List<QuickReply>> listCatalog(String botId) async {
    final items = await _catalog.listCatalog(botId);
    _cache[botId] = items;
    return items;
  }

  @override
  List<QuickReply>? cachedCatalog(String botId) => _cache[botId];

  @override
  void invalidate() => _cache.clear();
}
