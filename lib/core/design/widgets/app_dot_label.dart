import 'package:flutter/material.dart';

import '../tokens.dart';

/// Indicador quieto de estado: dot semántico + caption en `text2`.
///
/// Es el hermano sin cápsula del dot del [AppPill] — para estados ambientales
/// que se repiten por fila en las listas (sesión enlazada, IA activa), donde
/// una cápsula por fila acumula ruido. El color vive SOLO en el dot; el texto
/// se queda quieto en `text2` para que una lista sana no grite. Los estados
/// excepcionales (pausado, error) siguen mereciendo un pill completo.
class AppDotLabel extends StatelessWidget {
  const AppDotLabel({super.key, required this.color, required this.label});

  /// Color semántico del estado (success/danger/text2…): la única tinta.
  final Color color;

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          key: const ValueKey<String>('app_dot_label.dot'),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // Flexible: en anchos angostos el label cede y ellipsa en vez de
        // desbordar la fila que lo hospeda.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
        ),
      ],
    );
  }
}
