import 'package:flutter/material.dart';

import '../../../../core/design/app_selection_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_day_chips.dart';
import '../../../../core/design/widgets/app_time_range_field.dart';
import 'conditional_time_form.dart';
import 'conditional_time_zones.dart';
import 'step_type_selector.dart';

/// Campo del form que abre un selector rico (sheet) en vez de un dropdown:
/// misma anatomía visual que el select del kit en reposo —label arriba,
/// píldora con fill translúcido y chevron— pero el tap delega en [onTap],
/// que muestra el `showAppSelectionSheet` correspondiente.
class CtSheetField extends StatelessWidget {
  const CtSheetField({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    required this.enabled,
    required this.onTap,
  });

  final String label;

  /// Selección vigente, ya legible. Null ⇒ se muestra [hint] atenuado.
  final String? value;

  final String? hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        Material(
          color: AppTokens.input,
          borderRadius: BorderRadius.circular(AppTokens.radiusField),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppTokens.radiusField),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp4,
                vertical: AppTokens.sp1,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      value ?? hint ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: value != null
                            ? AppTokens.text1
                            : AppTokens.text2,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppTokens.text2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    // Disabled: atenuar el bloque con el mismo idioma que los fields del kit.
    return Opacity(opacity: enabled ? 1.0 : 0.4, child: field);
  }
}

/// Abre el selector rico de zona horaria: el set curado con nombre humano
/// (id IANA como caption) y, si la tz vigente no está en el set, una opción
/// extra que la representa — la configuración existente siempre es elegible
/// y visible. Devuelve la tz elegida o null si el operador descarta.
Future<String?> showCtTimezonePicker(
  BuildContext context, {
  required String current,
}) {
  final isCurated = ctCuratedTimezones.any((z) => z.id == current);
  return showAppSelectionSheet<String>(
    context,
    title: 'Zona horaria',
    selected: current,
    sections: <AppSelectionSection<String>>[
      if (!isCurated)
        AppSelectionSection<String>(
          options: <AppSelectionOption<String>>[
            AppSelectionOption<String>(
              key: const Key('ct_form.tz_option.current'),
              value: current,
              title: current,
              caption: 'Zona actual de este condicional',
            ),
          ],
        ),
      AppSelectionSection<String>(
        options: <AppSelectionOption<String>>[
          for (final z in ctCuratedTimezones)
            AppSelectionOption<String>(
              key: Key('ct_form.tz_option.${z.id}'),
              value: z.id,
              title: z.label,
              caption: z.id,
            ),
        ],
      ),
    ],
  );
}

/// Abre el selector rico de destino de rama: cada opción es un paso
/// candidato con su posición vigente, el glifo de su tipo y un preview de
/// una línea del contenido — el operador reconoce el paso sin salir del
/// sheet. Devuelve el id del paso elegido o null si descarta.
Future<String?> showCtTargetPicker(
  BuildContext context, {
  required String title,
  required List<CtTargetOption> targets,
  String? selected,
}) {
  return showAppSelectionSheet<String>(
    context,
    title: title,
    selected: selected,
    sections: <AppSelectionSection<String>>[
      AppSelectionSection<String>(
        options: <AppSelectionOption<String>>[
          for (final t in targets)
            AppSelectionOption<String>(
              key: Key('ct_form.target_option.${t.id}'),
              value: t.id,
              title: '${t.order + 1}. ${t.label}',
              leading: Icon(
                stepTypeGlyph(t.type),
                size: 20,
                color: AppTokens.text2,
              ),
            ),
        ],
      ),
    ],
  );
}

/// Bloque visual de UNA ventana horaria del form CONDITIONAL_TIME: días de
/// la semana con el selector circular del kit y rango hh:mm editable por
/// teclado. Presentacional puro: el estado vive en el form, que recibe cada
/// cambio por callback.
///
/// Las keys de los controles heredan el contrato de tests del form:
/// `ct_form.window.<i>.day.<d>`, `ct_form.window.<i>.start/.end`,
/// `ct_form.window.<i>.remove`.
class CtWindowBlock extends StatelessWidget {
  const CtWindowBlock({
    super.key,
    required this.index,
    required this.daysUi,
    required this.range,
    required this.enabled,
    required this.removable,
    required this.onDaysChanged,
    required this.onRangeChanged,
    required this.onRemove,
  });

  final int index;

  /// Días seleccionados en índices de UI (0=lunes .. 6=domingo).
  final Set<int> daysUi;

  final AppTimeRange range;
  final bool enabled;
  final bool removable;
  final ValueChanged<Set<int>> onDaysChanged;
  final ValueChanged<AppTimeRange> onRangeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp3),
      decoration: BoxDecoration(
        border: Border.all(color: AppTokens.divider),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Ventana ${index + 1}',
                  style: textTheme.labelMedium,
                ),
              ),
              if (removable)
                IconButton(
                  key: Key('ct_form.window.$index.remove'),
                  tooltip: 'Eliminar ventana',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTokens.danger,
                  ),
                  onPressed: enabled ? onRemove : null,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          AppDayChips(
            keyPrefix: 'ct_form.window.$index',
            selected: daysUi,
            onChanged: enabled ? onDaysChanged : null,
          ),
          const SizedBox(height: AppTokens.sp3),
          // El propio campo de rango explica el desorden (inicio ≥ fin);
          // aquí solo se agrega el motivo que el campo no conoce: sin días
          // la ventana tampoco es guardable.
          AppTimeRangeField(
            keyPrefix: 'ct_form.window.$index',
            value: range,
            onChanged: enabled ? onRangeChanged : null,
          ),
          if (daysUi.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.sp2),
              child: Text(
                'Selecciona al menos un día',
                style: textTheme.labelSmall?.copyWith(color: AppTokens.danger),
              ),
            ),
        ],
      ),
    );
  }
}
