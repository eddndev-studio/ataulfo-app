import 'package:flutter/material.dart';

import '../tokens.dart';

/// Sección colapsable "Razonamiento" sobre un turno del assistant: el operador
/// ve POR QUÉ el modelo respondió así, sin que ocupe espacio por defecto. El
/// razonamiento es telemetría — se muestra, jamás se re-alimenta al modelo.
/// Compartida por el asistente de plataforma, el entrenador y la observabilidad.
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
      // El fondo lo da un Material (no un DecoratedBox con color): el ListTile
      // interno del ExpansionTile pinta su superficie y tinte sobre el Material
      // ancestro más cercano; si el color viviera en un DecoratedBox intermedio
      // lo taparía.
      child: Material(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: Key('reasoning.disclosure.$keyId'),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppTokens.sp3,
              0,
              AppTokens.sp3,
              AppTokens.sp3,
            ),
            leading: const Icon(
              Icons.psychology_outlined,
              size: 18,
              color: AppTokens.text2,
            ),
            title: Text(
              'Razonamiento',
              style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  reasoning,
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
