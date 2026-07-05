import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';

/// Tarjeta colapsable de UNA variable en el editor compacto de overrides.
///
/// Puramente presentacional: el form padre posee el `TextEditingController`
/// y decide expandido/colapsado; la tarjeta pinta el header (nombre +
/// descripción + preview del valor cuando está colapsada) y, expandida, el
/// [field] editable que el padre construye. Tocar la tarjeta invoca
/// [onToggle]; un tap DENTRO del campo de texto lo gana el propio TextField
/// (gesture arena), así que editar no colapsa.
class BotVariableCard extends StatelessWidget {
  const BotVariableCard({
    super.key,
    required this.name,
    required this.description,
    required this.valueText,
    required this.expanded,
    required this.onToggle,
    required this.field,
  });

  final String name;
  final String description;

  /// Texto ACTUAL del controller (vivo, no solo el override guardado):
  /// alimenta el preview de una línea cuando la tarjeta está colapsada, de
  /// modo que lo escrito y aún no guardado también se señala.
  final String valueText;

  final bool expanded;
  final VoidCallback onToggle;

  /// Campo editable construido por el padre — dueño del controller y de la
  /// Key contractual `bot_variables.field.<name>`.
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasValue = valueText.trim().isNotEmpty;
    return AppCard(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(name, style: t.titleMedium),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: AppTokens.text2),
                        ),
                      ),
                    // Colapsada con valor: preview de UNA línea (los saltos
                    // se aplanan a espacio) — señal de «configurada» sin
                    // expandir. Expandida no lo pinta: el campo ya muestra
                    // el texto completo.
                    if (!expanded && hasValue)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.sp1),
                        child: Text(
                          valueText.replaceAll('\n', ' '),
                          key: Key('bot_variables.preview.$name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(
                            color: AppTokens.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.sp2),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: AppTokens.text2,
              ),
            ],
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: AppTokens.sp3),
            field,
          ],
        ],
      ),
    );
  }
}
