import 'entities/message.dart';

/// Un emoji de reacción agregado sobre un mensaje, con cuántos remitentes lo
/// pusieron. WhatsApp muestra el emoji y —si más de uno reaccionó igual— el
/// conteo.
class ReactionTally {
  const ReactionTally(this.emoji, this.count);

  final String emoji;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ReactionTally && other.emoji == emoji && other.count == count;

  @override
  int get hashCode => Object.hash(emoji, count);

  @override
  String toString() => 'ReactionTally($emoji, $count)';
}

/// Resultado de doblar las reacciones de un hilo: los mensajes que SÍ se pintan
/// como burbuja (`renderable`, sin las reacciones) y el agregado de reacciones
/// por mensaje target (`byTarget`, keyed por `externalId`).
typedef FoldedThread = ({
  List<Message> renderable,
  Map<String, List<ReactionTally>> byTarget,
});

/// Dobla los mensajes `type:"reaction"` sobre su mensaje target en vez de
/// pintarlos como burbuja propia. Las reacciones llegan como mensajes normales
/// (`content` = emoji, `quotedId` = externalId del target); el backend NO las
/// agrega, se agregan aquí en el cliente.
///
/// Semántica WhatsApp: un remitente tiene **a lo sumo una** reacción por
/// mensaje —la última gana—, y un emoji vacío **la quita**. Por eso se reduce
/// primero a (target → remitente → emoji) en orden de llegada, y recién después
/// se cuenta por emoji. `all` se asume en orden causal (ASC), como lo entrega
/// el hilo. Una reacción sin target (`quotedId` null) se descarta.
FoldedThread foldReactions(List<Message> all) {
  final renderable = <Message>[];
  final perTargetSender = <String, Map<String, String>>{};

  for (final m in all) {
    if (m.type != 'reaction') {
      renderable.add(m);
      continue;
    }
    final target = m.quotedId;
    if (target == null) {
      continue; // reacción huérfana: ni se pinta ni cuenta
    }
    final bySender = perTargetSender.putIfAbsent(
      target,
      () => <String, String>{},
    );
    if (m.content.isEmpty) {
      bySender.remove(m.senderLid); // quitar reacción
    } else {
      bySender[m.senderLid] = m.content; // poner/reemplazar
    }
  }

  final byTarget = <String, List<ReactionTally>>{};
  perTargetSender.forEach((target, bySender) {
    final counts = <String, int>{};
    for (final emoji in bySender.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    if (counts.isNotEmpty) {
      byTarget[target] = <ReactionTally>[
        for (final entry in counts.entries)
          ReactionTally(entry.key, entry.value),
      ];
    }
  });

  return (renderable: renderable, byTarget: byTarget);
}
