import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/copy_text_actions.dart';

/// Card colapsada del prompt del sistema de una plantilla. Un prompt entrenado
/// puede medir miles de caracteres: pintarlo entero empujaba el CTA de entrenar
/// fuera de alcance, así que aquí solo va un encabezado con la meta de tamaño y
/// un preview recortado. "Ver completo" abre una hoja alta con el texto
/// seleccionable y la acción de copiar. Vacío ⇒ un placeholder en itálica.
///
/// El prompt se LEE aquí; se EDITA conversando con el Entrenador (el CTA de la
/// página lleva ahí), por eso esta card no ofrece edición en sitio.
class TemplatePromptCard extends StatelessWidget {
  const TemplatePromptCard({super.key, required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (prompt.isEmpty) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text('Prompt del sistema', style: textTheme.titleMedium),
          ),
          const SizedBox(width: AppTokens.sp3),
          Text(
            'Sin prompt definido',
            style: textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppTokens.text2,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Prompt del sistema', style: textTheme.titleMedium),
            ),
            const SizedBox(width: AppTokens.sp3),
            Text(
              _charCountLabel(prompt.length),
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sp3),
        Text(
          key: const Key('template_ai.prompt.preview'),
          prompt,
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: AppTokens.sp2),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.text(
            key: const Key('template_ai.prompt.view_full'),
            label: 'Ver completo',
            icon: Icons.unfold_more,
            onPressed: () => _showFull(context),
          ),
        ),
      ],
    );
  }

  /// Hoja alta (~90%) con el prompt entero, seleccionable y con scroll propio.
  /// Copiar vuelve a la página (donde el aviso es visible) y confirma.
  void _showFull(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    showAppBottomSheet<void>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.9,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp5,
            0,
            AppTokens.sp5,
            AppTokens.sp4 + sheetContext.sheetBottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Prompt del sistema',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  AppButton.text(
                    key: const Key('template_ai.prompt.copy'),
                    label: 'Copiar',
                    icon: Icons.copy_outlined,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      copyTextToClipboard(
                        rootNavigator.context,
                        prompt,
                        confirm: 'Prompt copiado',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp3),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    prompt,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Meta legible del tamaño del prompt. A partir de mil caracteres se abrevia en
/// miles ("3.4k caracteres") para que la cifra no domine el encabezado.
String _charCountLabel(int count) {
  if (count == 1) return '1 carácter';
  if (count < 1000) return '$count caracteres';
  return '${(count / 1000).toStringAsFixed(1)}k caracteres';
}
