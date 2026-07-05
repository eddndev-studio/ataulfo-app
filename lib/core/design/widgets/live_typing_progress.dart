import 'package:flutter/material.dart';

import '../tokens.dart';
import 'typing_bubble.dart';

/// Indicador en vivo del turno de un agente: la burbuja de "escribiendo"
/// ([TypingBubble]) más la etiqueta de progreso que emite el SSE ("Pensando…",
/// "Usando {tool}…"). Sin etiqueta (el SSE no conectó aún) muestra solo el
/// typing. Compartido por las superficies de chat con turno síncrono
/// (entrenador, asistente de plataforma).
class LiveTypingProgress extends StatelessWidget {
  const LiveTypingProgress({
    required this.label,
    required this.keyId,
    super.key,
  });

  final String label;

  /// Prefijo de las Keys internas (`<keyId>.typing`, `<keyId>.live_progress`)
  /// para que cada superficie conserve identificadores propios en tests.
  final String keyId;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        TypingBubble(key: Key('$keyId.typing')),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppTokens.sp2),
          Flexible(
            child: Text(
              label,
              key: Key('$keyId.live_progress'),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
        ],
      ],
    );
  }
}
