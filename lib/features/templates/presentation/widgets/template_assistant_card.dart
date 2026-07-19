import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';

String templateAssistantLocation({
  required String templateId,
  required String templateName,
}) => Uri(
  path: '/home',
  queryParameters: <String, String>{
    'prompt':
        'Quiero trabajar en el Asistente "$templateName" '
        '(ID: $templateId). Lee su estado actual y ayúdame a ',
  },
).toString();

/// Handoff al agente org-scoped. Prompt, corridas y documentos son
/// capacidades del mismo hilo; el Asistente viaja como contexto explícito y
/// editable, no como scope oculto de otra pantalla.
class TemplateAssistantCard extends StatelessWidget {
  const TemplateAssistantCard({
    super.key,
    required this.templateId,
    required this.templateName,
  });

  final String templateId;
  final String templateName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('template_detail.card.assistant'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppEntityIcon(
                icon: Icons.auto_awesome,
                size: 48,
                highlighted: true,
              ),
              const SizedBox(width: AppTokens.sp4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Trabajar con Ataúlfo', style: textTheme.titleMedium),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      'Ajusta el comportamiento, revisa corridas y crea recursos '
                      'sin salir de tu hilo de trabajo.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.filled(
            key: const Key('template_detail.assistant'),
            label: 'Abrir en el asistente',
            icon: Icons.arrow_forward,
            fullWidth: true,
            onPressed: () => context.go(
              templateAssistantLocation(
                templateId: templateId,
                templateName: templateName,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
