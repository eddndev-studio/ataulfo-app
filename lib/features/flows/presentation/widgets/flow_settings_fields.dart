import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_slider.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';

/// Milisegundos por hora: el cooldown se expone en horas pero el wire es ms.
const int kFlowSettingsMsPerHour = 60 * 60 * 1000;

/// Tope del cooldown en horas (5 días). Espeja FlowMaxCooldownMs del backend.
const int kFlowSettingsMaxCooldownHours = 120;

/// Toggle "Invocable por IA" (allowlist S11 RF#17): autoriza al agente IA
/// conversacional a listar y ejecutar este flujo. Apagado por defecto — que
/// un LLM dispare una automatización es opt-in explícito del operador.
class FlowSettingsAiInvocableField extends StatelessWidget {
  const FlowSettingsAiInvocableField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.textTheme,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Invocable por IA',
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp1),
              Text(
                'El agente IA puede lanzar este flujo en una conversación.',
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.sp3),
        AppSwitch(
          key: const Key('flow_settings.ai_invocable.switch'),
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class FlowSettingsCooldownField extends StatelessWidget {
  const FlowSettingsCooldownField({
    super.key,
    required this.hours,
    required this.onChanged,
    required this.textTheme,
  });

  final double hours;
  final ValueChanged<double> onChanged;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _label(hours.round()),
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        AppSlider(
          key: const Key('flow_settings.cooldown.slider'),
          value: hours,
          min: 0,
          max: kFlowSettingsMaxCooldownHours.toDouble(),
          // Granularidad de 1 hora en todo el rango [0, 5 días].
          divisions: kFlowSettingsMaxCooldownHours,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// Label humanizado del cooldown en horas: "Sin espera" (0), "Xh" (<24h),
  /// "Xd" / "Xd Yh" (días). El swatch de horas se compone con días para que
  /// 5 días se lea "5d" y 25h se lea "1d 1h".
  static String _label(int hours) {
    if (hours == 0) return 'Cooldown · Sin espera entre ejecuciones';
    final days = hours ~/ 24;
    final rem = hours % 24;
    final parts = <String>[if (days > 0) '${days}d', if (rem > 0) '${rem}h'];
    return 'Cooldown · ${parts.join(' ')} entre ejecuciones';
  }
}

class FlowSettingsUsageLimitField extends StatelessWidget {
  const FlowSettingsUsageLimitField({
    super.key,
    required this.controller,
    required this.textTheme,
  });

  final TextEditingController controller;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // El padre cabla el listener una sola vez en initState (es donde
    // vive el controller); este widget solo pinta.
    final isUnlimited =
        controller.text.trim().isEmpty || controller.text == '0';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Límite de ejecuciones',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
            if (isUnlimited)
              Text(
                'Sin límite',
                key: const Key('flow_settings.usage_limit.unlimited_label'),
                style: textTheme.labelSmall?.copyWith(
                  color: AppTokens.text2,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.sp2),
        AppTextField(
          key: const Key('flow_settings.usage_limit.field'),
          label: '',
          hint: 'Sin límite',
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ],
    );
  }
}

class FlowSettingsExcludesPicker extends StatelessWidget {
  const FlowSettingsExcludesPicker({
    super.key,
    required this.siblings,
    required this.siblingsFailed,
    required this.selected,
    required this.onToggle,
    required this.textTheme,
  });

  final List<fdom.Flow> siblings;
  final bool siblingsFailed;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Excluir mientras estos flujos corren',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        if (siblingsFailed)
          Text(
            'No pudimos cargar otros flujos. Reintenta el detalle del flujo.',
            key: const Key('flow_settings.excludes.siblings_failed'),
            style: textTheme.bodySmall?.copyWith(
              color: AppTokens.warning,
              fontStyle: FontStyle.italic,
            ),
          )
        else if (siblings.isEmpty)
          Text(
            'No hay otros flujos en esta plantilla.',
            key: const Key('flow_settings.excludes.empty'),
            style: textTheme.bodySmall?.copyWith(
              color: AppTokens.text2,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              for (final s in siblings)
                AppChoiceChip(
                  key: Key('flow_settings.excludes.chip.${s.id}'),
                  label: s.name,
                  selected: selected.contains(s.id),
                  onSelected: (_) => onToggle(s.id),
                ),
            ],
          ),
      ],
    );
  }
}

class FlowSettingsSavingIndicator extends StatelessWidget {
  const FlowSettingsSavingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: Key('flow_settings.saving'),
    height: 2,
    child: LinearProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class FlowSettingsFailureCopy extends StatelessWidget {
  const FlowSettingsFailureCopy({super.key, required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (key, copy, showReload) = _resolve(failure);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy,
          key: Key(key),
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
        ),
        if (showReload) ...<Widget>[
          const SizedBox(height: AppTokens.sp2),
          AppButton.tonal(
            key: const Key('flow_settings.error.conflict.reload'),
            label: 'Recargar',
            onPressed: () => context.read<FlowDetailBloc>().add(
              const FlowDetailLoadRequested(),
            ),
          ),
        ],
      ],
    );
  }

  static (String key, String copy, bool showReload) _resolve(FlowsFailure f) =>
      switch (f) {
        FlowsConflictFailure() => (
          'flow_settings.error.conflict',
          'Otro operador editó esta configuración. Recarga antes de guardar.',
          true,
        ),
        FlowsInvalidSettingsFailure() => (
          'flow_settings.error.invalid_settings',
          'Revisa cooldown y límite: deben estar dentro del rango permitido.',
          false,
        ),
        FlowsNotFoundFailure() => (
          'flow_settings.error.not_found',
          'Este flujo ya no existe en tu organización.',
          false,
        ),
        FlowsForbiddenFailure() => (
          'flow_settings.error.forbidden',
          'Tu rol no permite editar la configuración. Pide acceso a un admin.',
          false,
        ),
        FlowsNetworkFailure() || FlowsTimeoutFailure() => (
          'flow_settings.error.network',
          'Sin conexión con el servidor. Revisa tu red y reintenta.',
          false,
        ),
        FlowsServerFailure() => (
          'flow_settings.error.server',
          'El servidor falló al guardar. Inténtalo de nuevo.',
          false,
        ),
        FlowsInvalidCreateFailure() ||
        FlowsInvalidStepFailure() ||
        FlowsStepNotFoundFailure() ||
        FlowsInvalidReorderFailure() ||
        FlowsStepReferencedFailure() ||
        UnknownFlowsFailure() => (
          'flow_settings.error.unknown',
          'No pudimos guardar la configuración. Inténtalo de nuevo.',
          false,
        ),
      };
}
