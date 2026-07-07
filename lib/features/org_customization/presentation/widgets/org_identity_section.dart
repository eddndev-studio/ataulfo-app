import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';

/// Identidad de la organización: el nombre visible (el mismo que llevan los
/// documentos generados) con la acción de renombrar. El nombre puede llegar
/// vacío (memberships caído): se muestra un placeholder honesto y renombrar
/// se deshabilita — sin nombre actual la hoja no tiene qué precargar.
class OrgIdentitySection extends StatelessWidget {
  const OrgIdentitySection({
    super.key,
    required this.orgName,
    required this.enabled,
    required this.onRename,
  });

  final String orgName;
  final bool enabled;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasName = orgName.trim().isNotEmpty;
    return AppCard(
      key: const Key('org_customization.card.identity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Nombre',
            style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            hasName ? orgName : 'Sin nombre disponible',
            key: const Key('org_customization.name'),
            style: textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Con tu marca configurada, aparece junto al logo en el membrete '
            'y el pie de los documentos que genera el asistente.',
            style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.tonal(
            key: const Key('org_customization.rename'),
            label: 'Renombrar organización',
            fullWidth: true,
            onPressed: enabled && hasName ? onRename : null,
          ),
        ],
      ),
    );
  }
}
