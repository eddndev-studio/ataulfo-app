import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';

/// Tab "Configuración" del editor de flujo (S11). Edita los tres gates
/// del flow: `cooldownMs` (slider 0–300s), `usageLimit` (number field,
/// 0 = sin límite) y `excludesFlows[]` (multi-select de chips con los
/// otros flujos de la Template).
///
/// Lee el snapshot del `FlowDetailBloc` (Loaded / SettingsSaving /
/// SettingsSaveFailed) y delega el guardado al mismo bloc vía
/// `FlowDetailUpdateSettingsRequested`. Tras un save exitoso el bloc
/// emite Loaded con la version incrementada; el form re-hidrata
/// automáticamente porque el sub-tree usa `ValueKey<int>(flow.version)`
/// como llave de identidad.
///
/// Estados de fallo cubiertos por copy inline (sin SnackBar):
/// `Conflict` ⇒ "version stale" + botón Recargar (re-load del detail);
/// `InvalidSettings` ⇒ "revisa cooldown/límite";
/// `NotFound / Forbidden / Network / Server` ⇒ copy específico.
class FlowSettingsTab extends StatelessWidget {
  const FlowSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowDetailBloc, FlowDetailState>(
      builder: (context, state) {
        final (
          fdom.Flow? flow,
          List<fdom.Flow> siblings,
          bool siblingsFailed,
          bool isSaving,
          FlowsFailure? failure,
        ) = switch (state) {
          FlowDetailLoaded(
            :final flow,
            :final siblings,
            :final siblingsFailed,
          ) =>
            (flow, siblings, siblingsFailed, false, null),
          FlowDetailSettingsSaving(
            :final flow,
            :final siblings,
            :final siblingsFailed,
          ) =>
            (flow, siblings, siblingsFailed, true, null),
          FlowDetailSettingsSaveFailed(
            :final flow,
            :final siblings,
            :final siblingsFailed,
            :final failure,
          ) =>
            (flow, siblings, siblingsFailed, false, failure),
          FlowDetailLoading() || FlowDetailFailed() => (
            null,
            const <fdom.Flow>[],
            false,
            false,
            null,
          ),
        };

        if (flow == null) {
          return const SizedBox.shrink();
        }

        return _SettingsForm(
          key: ValueKey<int>(flow.version),
          flow: flow,
          siblings: siblings,
          siblingsFailed: siblingsFailed,
          isSaving: isSaving,
          failure: failure,
        );
      },
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    super.key,
    required this.flow,
    required this.siblings,
    required this.siblingsFailed,
    required this.isSaving,
    required this.failure,
  });

  final fdom.Flow flow;
  final List<fdom.Flow> siblings;
  final bool siblingsFailed;
  final bool isSaving;
  final FlowsFailure? failure;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  // El slider expone cooldown en SEGUNDOS (0–300) para legibilidad
  // humana; al guardar lo convertimos a ms. Reading inicial: ms del
  // wire ÷ 1000 redondeado.
  late double _cooldownSeconds;

  late final TextEditingController _usageLimitCtrl;
  late Set<String> _excludes;

  @override
  void initState() {
    super.initState();
    _cooldownSeconds = (widget.flow.cooldownMs / 1000).clamp(0, 300).toDouble();
    _usageLimitCtrl = TextEditingController(
      // 0 ⇒ campo vacío para que el placeholder "Sin límite" sea visible.
      text: widget.flow.usageLimit > 0 ? widget.flow.usageLimit.toString() : '',
    );
    _excludes = <String>{...widget.flow.excludesFlows};
  }

  @override
  void dispose() {
    _usageLimitCtrl.dispose();
    super.dispose();
  }

  int get _cooldownMs => (_cooldownSeconds * 1000).round();

  int get _usageLimit => int.tryParse(_usageLimitCtrl.text.trim()) ?? 0;

  /// excludesFlows ordenado ASC por id antes de comparar / despachar.
  /// El orden no es semántico del dominio: ordenarlo evita PUTs no-op
  /// cuando el operador selecciona los mismos flujos en otro orden.
  List<String> get _excludesSorted {
    final out = _excludes.toList()..sort();
    return out;
  }

  bool get _isDirty {
    if (_cooldownMs != widget.flow.cooldownMs) return true;
    if (_usageLimit != widget.flow.usageLimit) return true;
    final snapshot = <String>[...widget.flow.excludesFlows]..sort();
    final local = _excludesSorted;
    if (local.length != snapshot.length) return true;
    for (var i = 0; i < local.length; i++) {
      if (local[i] != snapshot[i]) return true;
    }
    return false;
  }

  void _submit() {
    context.read<FlowDetailBloc>().add(
      FlowDetailUpdateSettingsRequested(
        cooldownMs: _cooldownMs,
        usageLimit: _usageLimit,
        excludesFlows: _excludesSorted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canSave = _isDirty && !widget.isSaving;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CooldownField(
            seconds: _cooldownSeconds,
            onChanged: (v) => setState(() => _cooldownSeconds = v),
            textTheme: textTheme,
          ),
          const SizedBox(height: AppTokens.sp6),
          _UsageLimitField(
            controller: _usageLimitCtrl,
            onChanged: () => setState(() {}),
            textTheme: textTheme,
          ),
          const SizedBox(height: AppTokens.sp6),
          _ExcludesPicker(
            siblings: widget.siblings,
            siblingsFailed: widget.siblingsFailed,
            selected: _excludes,
            onToggle: (id) => setState(() {
              if (_excludes.contains(id)) {
                _excludes.remove(id);
              } else {
                _excludes.add(id);
              }
            }),
            textTheme: textTheme,
          ),
          const SizedBox(height: AppTokens.sp6),
          if (widget.failure != null) ...<Widget>[
            _FailureCopy(failure: widget.failure!),
            const SizedBox(height: AppTokens.sp4),
          ],
          if (widget.isSaving) ...<Widget>[
            const _SavingInlineSpinner(),
            const SizedBox(height: AppTokens.sp3),
          ],
          AppButton.filled(
            key: const Key('flow_settings.save_button'),
            label: 'Guardar',
            onPressed: canSave ? _submit : null,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _CooldownField extends StatelessWidget {
  const _CooldownField({
    required this.seconds,
    required this.onChanged,
    required this.textTheme,
  });

  final double seconds;
  final ValueChanged<double> onChanged;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final label = seconds == 0
        ? 'Cooldown · Sin espera entre ejecuciones'
        : 'Cooldown · ${seconds.toStringAsFixed(0)}s entre ejecuciones';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTokens.primary,
            inactiveTrackColor: AppTokens.surface3,
            thumbColor: AppTokens.primary,
            overlayColor: AppTokens.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            key: const Key('flow_settings.cooldown.slider'),
            value: seconds,
            min: 0,
            max: 300,
            divisions: 60,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _UsageLimitField extends StatelessWidget {
  const _UsageLimitField({
    required this.controller,
    required this.onChanged,
    required this.textTheme,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // Cualquier cambio rebota onChanged para que el dirty-check del
    // padre se reevalúe.
    controller.removeListener(onChanged);
    controller.addListener(onChanged);
    final isUnlimited = controller.text.trim().isEmpty || controller.text == '0';
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

class _ExcludesPicker extends StatelessWidget {
  const _ExcludesPicker({
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
                _ExcludeChip(
                  key: Key('flow_settings.excludes.chip.${s.id}'),
                  flow: s,
                  isSelected: selected.contains(s.id),
                  onTap: () => onToggle(s.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _ExcludeChip extends StatelessWidget {
  const _ExcludeChip({
    super.key,
    required this.flow,
    required this.isSelected,
    required this.onTap,
  });

  final fdom.Flow flow;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      child: isSelected
          ? AppPill.primary(label: flow.name)
          : AppPill.outline(label: flow.name),
    );
  }
}

class _SavingInlineSpinner extends StatelessWidget {
  const _SavingInlineSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: Key('flow_settings.saving'),
    height: 2,
    child: LinearProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _FailureCopy extends StatelessWidget {
  const _FailureCopy({required this.failure});

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
        UnknownFlowsFailure() => (
          'flow_settings.error.unknown',
          'No pudimos guardar la configuración. Inténtalo de nuevo.',
          false,
        ),
      };
}
