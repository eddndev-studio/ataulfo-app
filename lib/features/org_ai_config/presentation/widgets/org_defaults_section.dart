import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_section_header.dart';
import '../../../ai_catalog/domain/entities/catalog.dart';
import '../../../ai_catalog/presentation/widgets/ai_config_editor.dart';
import '../../../templates/domain/entities/template.dart';

/// Sección de defaults de IA de la org sobre el [AiConfigEditor] compartido:
/// lo que heredan las plantillas NUEVAS al crearse. Sin estado propio: lee
/// `defaults` y emite el AIConfig editado por [onChanged] (la fuente de verdad
/// es el bloc, que acumula hasta el Guardar explícito de la pantalla).
///
/// Solo los campos básicos del editor: silencio/tool-groups/subagente/
/// seguimiento son semántica de plantilla y no tienen default de org. El
/// proveedor se elige junto al modelo en el picker agrupado. El system prompt
/// por defecto NO se edita aquí (las plantillas nuevas nacen con prompt vacío;
/// el prompt se ajusta por plantilla).
class OrgDefaultsSection extends StatelessWidget {
  const OrgDefaultsSection({
    super.key,
    required this.catalog,
    required this.defaults,
    required this.enabled,
    required this.onChanged,
  });

  static const Set<AiConfigField> _fields = <AiConfigField>{
    AiConfigField.enabled,
    AiConfigField.model,
    AiConfigField.temperature,
    AiConfigField.thinking,
    AiConfigField.contextMessages,
    AiConfigField.responseDelay,
  };

  final Catalog catalog;
  final AIConfig defaults;
  final bool enabled;
  final void Function(AIConfig) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(
          title: 'Valores por defecto',
          caption:
              'Lo que heredan las plantillas nuevas de la organización al '
              'crearse. No afecta a las plantillas existentes.',
        ),
        const SizedBox(height: AppTokens.sp4),
        AiConfigEditor(
          keyPrefix: 'org_ai.defaults',
          ai: defaults,
          catalog: catalog,
          fields: _fields,
          editable: enabled,
          enabledLabel: 'IA activa por defecto',
          enabledCaption:
              'Las plantillas nuevas nacen con la IA encendida o apagada '
              'según este valor.',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
