import 'package:flutter/material.dart';

import '../../util/smart_timestamp.dart';
import '../tokens.dart';

/// Caption de hora bajo un mensaje de chat: cuándo se dijo. Usa el formateo
/// inteligente compartido (hoy → HH:mm; ayer/otros días → con fecha). Aditivo —
/// no toca la burbuja; se apila debajo. `now` es inyectable para tests.
class MessageTimestamp extends StatelessWidget {
  const MessageTimestamp({required this.at, this.now, super.key});

  final DateTime at;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        smartTimestamp(at.millisecondsSinceEpoch, now: now),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
      ),
    );
  }
}
