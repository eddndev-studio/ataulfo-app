import 'package:flutter/material.dart';

import '../../../features/templates/domain/entities/template.dart';
import '../tokens.dart';

/// Etiqueta humanizada del proveedor de IA de una template.
///
/// Centraliza el label que antes vivía duplicado como `_providerLabel`
/// en los 3 consumidores de `AIProvider` (listado, detalle, picker).
/// Hoy renderiza solo texto en `bodyMedium` text2; el widget queda
/// preparado para sumar un icono SVG de marca a la izquierda del
/// label cuando ese asset bundle aterrice — sin modificar callsites.
class ProviderBadge extends StatelessWidget {
  const ProviderBadge({super.key, required this.provider});

  final AIProvider provider;

  @override
  Widget build(BuildContext context) {
    return Text(
      _labelOf(provider),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
    );
  }

  static String _labelOf(AIProvider p) => switch (p) {
    AIProvider.openai => 'OpenAI',
    AIProvider.gemini => 'Gemini',
    AIProvider.minimax => 'MiniMax',
    AIProvider.deepseek => 'DeepSeek',
  };
}
