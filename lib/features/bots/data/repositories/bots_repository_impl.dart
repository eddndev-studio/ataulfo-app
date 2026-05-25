import '../../domain/entities/bot.dart';
import '../../domain/repositories/bots_repository.dart';
import '../datasources/bots_datasource.dart';

/// Implementación trivial del puerto: el listado no requiere cache local en
/// esta capa (la primera versión refresca contra el backend en cada open).
/// Cuando aterrice RFC-0001 (cache + sync), esta clase orquestará la verdad
/// local vs. remota; hoy es delegate.
class BotsRepositoryImpl implements BotsRepository {
  BotsRepositoryImpl({required BotsDatasource datasource}) : _ds = datasource;

  final BotsDatasource _ds;

  @override
  Future<List<Bot>> list() => _ds.list();

  @override
  Future<Bot> byId(String id) => _ds.byId(id);

  @override
  Future<Bot> create({
    required String templateId,
    required String name,
    required BotChannel channel,
  }) => _ds.create(templateId: templateId, name: name, channel: channel);
}
