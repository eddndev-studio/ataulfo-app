import 'conversation.dart';

class ConversationsPage {
  const ConversationsPage({required this.items, required this.nextCursor});

  final List<Conversation> items;
  final String? nextCursor;
}
