import 'message.dart';

/// Una página del hilo (S09, cola + paginación hacia atrás). `messages` llega
/// en orden ascendente (más viejo→más nuevo); `prevCursor` es el cursor opaco
/// para cargar el tramo MÁS VIEJO — `null` ⇒ se alcanzó el inicio del hilo.
///
/// El cliente no interpreta `prevCursor`: lo reenvía tal cual como `?cursor=`
/// en el siguiente GET hacia arriba.
class MessagePage {
  const MessagePage({required this.messages, required this.prevCursor});

  final List<Message> messages;
  final String? prevCursor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MessagePage) return false;
    if (other.prevCursor != prevCursor) return false;
    if (other.messages.length != messages.length) return false;
    for (var i = 0; i < messages.length; i++) {
      if (other.messages[i] != messages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(messages), prevCursor);
}
