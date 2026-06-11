import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';

/// Entrada destacada del Entrenador en el detalle de plantilla.
///
/// El entrenador es la superficie principal para evolucionar el prompt y el
/// workspace de la plantilla; merece una card propia y prominente, no un
/// icono de AppBar. La fila superior (glifo en gradiente + copy + chevron)
/// abre el chat del entrenador; debajo, sus dos superficies hermanas como
/// accesos compactos: el workspace de documentos y el preview sandbox.
class TrainerHeroCard extends StatelessWidget {
  const TrainerHeroCard({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('template_detail.card.trainer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            key: const Key('template_detail.trainer'),
            // push apila el entrenador sobre el detalle; el back físico
            // vuelve aquí.
            onTap: () => context.push('/templates/$templateId/trainer'),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: Row(
              children: <Widget>[
                const AppEntityIcon(
                  icon: Icons.school_outlined,
                  size: 48,
                  highlighted: true,
                ),
                const SizedBox(width: AppTokens.sp4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Entrenador', style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Entrena el prompt conversando con la IA',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.sp2),
                const Icon(Icons.chevron_right, color: AppTokens.text2),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.sp4),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.tonal(
                  key: const Key('template_detail.trainer.workspace'),
                  label: 'Workspace',
                  icon: Icons.folder_outlined,
                  onPressed: () =>
                      context.push('/templates/$templateId/trainer/workspace'),
                ),
              ),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: AppButton.tonal(
                  key: const Key('template_detail.trainer.preview'),
                  label: 'Probar bot',
                  icon: Icons.play_arrow_outlined,
                  onPressed: () =>
                      context.push('/templates/$templateId/trainer/preview'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
