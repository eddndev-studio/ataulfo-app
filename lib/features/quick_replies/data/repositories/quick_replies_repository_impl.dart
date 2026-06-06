import '../../domain/entities/quick_reply.dart';
import '../../domain/repositories/quick_replies_repository.dart';
import '../datasources/quick_replies_catalog_datasource.dart';

/// Implementación del puerto de catálogo de respuestas rápidas WhatsApp (S23).
/// Delega en el datasource del catálogo; aísla al bloc del transporte concreto.
class QuickRepliesRepositoryImpl implements QuickRepliesRepository {
  QuickRepliesRepositoryImpl({required QuickRepliesCatalogDatasource catalog})
    : _catalog = catalog;

  final QuickRepliesCatalogDatasource _catalog;

  @override
  Future<List<QuickReply>> listCatalog(String botId) =>
      _catalog.listCatalog(botId);
}
