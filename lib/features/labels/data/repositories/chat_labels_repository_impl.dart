import '../../domain/entities/label.dart';
import '../../domain/repositories/chat_labels_repository.dart';
import '../datasources/chat_labels_datasource.dart';

/// Implementación trivial del puerto: delega en el datasource. Sin cache local
/// en esta capa (la carga del sheet siempre pide la verdad fresca al abrir).
class ChatLabelsRepositoryImpl implements ChatLabelsRepository {
  ChatLabelsRepositoryImpl({required ChatLabelsDatasource datasource})
    : _ds = datasource;

  final ChatLabelsDatasource _ds;

  @override
  Future<List<Label>> listForChat(String botId, String chatLid) =>
      _ds.listForChat(botId, chatLid);
}
