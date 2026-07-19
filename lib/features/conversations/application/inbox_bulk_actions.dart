import '../../labels/domain/repositories/chat_labels_repository.dart';
import '../../messages/domain/repositories/messages_repository.dart';
import '../domain/entities/conversation.dart';

/// Identidad estable de una fila de Bandeja. `chatLid` sólo es único dentro de
/// un Canal, por eso toda selección y resultado conserva ambos componentes.
class InboxConversationRef {
  const InboxConversationRef({required this.botId, required this.chatLid});

  factory InboxConversationRef.fromConversation(Conversation conversation) =>
      InboxConversationRef(
        botId: conversation.botId,
        chatLid: conversation.chatLid,
      );

  final String botId;
  final String chatLid;

  @override
  bool operator ==(Object other) =>
      other is InboxConversationRef &&
      other.botId == botId &&
      other.chatLid == chatLid;

  @override
  int get hashCode => Object.hash(botId, chatLid);
}

/// Resultado agregado de un fan-out. No filtra errores de infraestructura a
/// la UI: ésta sólo necesita informar N/M y conservar los fallos seleccionados.
class InboxBulkResult {
  InboxBulkResult({
    required Set<InboxConversationRef> attempted,
    required Set<InboxConversationRef> succeeded,
    required Set<InboxConversationRef> failed,
  }) : attempted = Set<InboxConversationRef>.unmodifiable(attempted),
       succeeded = Set<InboxConversationRef>.unmodifiable(succeeded),
       failed = Set<InboxConversationRef>.unmodifiable(failed);

  final Set<InboxConversationRef> attempted;
  final Set<InboxConversationRef> succeeded;
  final Set<InboxConversationRef> failed;

  int get attemptedCount => attempted.length;
  int get succeededCount => succeeded.length;
  int get failedCount => failed.length;
}

/// Coordina acciones masivas reutilizando exclusivamente los endpoints por
/// conversación de S09/S10. El pequeño pool evita ráfagas mayores a cuatro y
/// cada fallo queda aislado para que los demás targets continúen.
class InboxBulkActions {
  InboxBulkActions({
    required MessagesRepository messages,
    required ChatLabelsRepository chatLabels,
    this.maxConcurrency = 4,
  }) : assert(maxConcurrency > 0),
       _messages = messages,
       _chatLabels = chatLabels;

  final MessagesRepository _messages;
  final ChatLabelsRepository _chatLabels;
  final int maxConcurrency;

  Future<InboxBulkResult> addLabel(
    List<Conversation> targets,
    String labelId,
  ) => _fanOut(
    targets,
    (target) => _chatLabels.addToChat(target.botId, target.chatLid, labelId),
  );

  Future<InboxBulkResult> removeLabel(
    List<Conversation> targets,
    String labelId,
  ) => _fanOut(
    targets,
    (target) =>
        _chatLabels.removeFromChat(target.botId, target.chatLid, labelId),
  );

  Future<InboxBulkResult> markRead(List<Conversation> targets) => _fanOut(
    targets,
    (target) => _messages.markRead(target.botId, target.chatLid),
  );

  Future<InboxBulkResult> clearHistory(List<Conversation> targets) => _fanOut(
    targets,
    (target) => _messages.clearHistory(target.botId, target.chatLid),
  );

  Future<InboxBulkResult> _fanOut(
    List<Conversation> targets,
    Future<void> Function(Conversation target) operation,
  ) async {
    final attempted = targets
        .map(InboxConversationRef.fromConversation)
        .toSet();
    final succeeded = <InboxConversationRef>{};
    final failed = <InboxConversationRef>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < targets.length) {
        final index = nextIndex++;
        final target = targets[index];
        final ref = InboxConversationRef.fromConversation(target);
        try {
          await operation(target);
          succeeded.add(ref);
        } catch (_) {
          failed.add(ref);
        }
      }
    }

    final workerCount = targets.length < maxConcurrency
        ? targets.length
        : maxConcurrency;
    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return InboxBulkResult(
      attempted: attempted,
      succeeded: succeeded,
      failed: failed,
    );
  }
}
