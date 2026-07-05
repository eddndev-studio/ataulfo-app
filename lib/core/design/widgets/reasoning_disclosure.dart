import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_disclosure_tile.dart';

/// Sección colapsable "Razonamiento" sobre un turno del assistant: el operador
/// ve POR QUÉ el modelo respondió así, sin que ocupe espacio por defecto. El
/// razonamiento es telemetría — se muestra, jamás se re-alimenta al modelo.
/// Compartida por el asistente de plataforma, el entrenador y la observabilidad.
///
/// Es una especialización del [AppDisclosureTile]: fija el ícono, el título y
/// el cuerpo (el razonamiento, seleccionable a la izquierda) del kit.
class ReasoningDisclosure extends StatelessWidget {
  const ReasoningDisclosure({
    required this.reasoning,
    this.keyId = '',
    super.key,
  });

  final String reasoning;

  /// Sufijo para una Key estable por turno (tests / preservación de estado).
  final String keyId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sp2),
      child: AppDisclosureTile(
        // La Key viaja al tile para conservar el estado de expansión por turno
        // cuando la lista de mensajes se reordena.
        key: Key('reasoning.disclosure.$keyId'),
        icon: Icons.psychology_outlined,
        title: 'Razonamiento',
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            reasoning,
            style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
        ),
      ),
    );
  }
}
