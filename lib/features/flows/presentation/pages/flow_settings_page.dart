import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../domain/entities/flow.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_detail_bloc.dart';
import '../widgets/flow_settings_fields.dart';

/// Página "Configuración" del flujo (`/flows/:id/settings`). Edita los
/// tres gates del flow: `cooldownMs` (slider en horas, 0–120h = hasta 5
/// días), `usageLimit` (number field, 0 = sin límite) y `excludesFlows[]`
/// (multi-select de chips con los otros flujos de la Template).
///
/// El bloc vive a nivel de ruta: el form dirty sobrevive mientras la
/// página esté en el stack y solo se descarta al salir de ella. Su modelo de guardado es
/// explícito (form dirty + Guardar + CAS por `version`), a diferencia del
/// apply-inmediato del resto del editor; la caption al tope lo hace
/// legible.
///
/// Lee el snapshot del `FlowDetailBloc` (Loaded / Mutating /
/// MutationFailed) y delega el guardado al mismo bloc vía
/// `FlowDetailUpdateSettingsRequested`. Tras un save exitoso el bloc
/// emite Loaded con la version incrementada; el form re-hidrata
/// automáticamente porque el sub-tree usa `ValueKey<int>(flow.version)`
/// como llave de identidad.
///
/// Estados de fallo del guardado cubiertos por copy inline (sin
/// SnackBar): `Conflict` ⇒ "version stale" + botón Recargar (re-load del
/// detail); `InvalidSettings` ⇒ "revisa cooldown/límite";
/// `NotFound / Forbidden / Network / Server` ⇒ copy específico.
class FlowSettingsPage extends StatelessWidget {
  const FlowSettingsPage({super.key});

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
          FlowDetailMutating(
            :final flow,
            :final siblings,
            :final siblingsFailed,
          ) =>
            (flow, siblings, siblingsFailed, true, null),
          FlowDetailMutationFailed(
            :final flow,
            :final siblings,
            :final siblingsFailed,
            :final failure,
          ) =>
            (flow, siblings, siblingsFailed, false, failure),
          FlowDetailLoading() ||
          FlowDetailDeleted() ||
          FlowDetailFailed() => (null, const <fdom.Flow>[], false, false, null),
        };

        if (flow == null) {
          return switch (state) {
            FlowDetailFailed(failure: final f) => _PageFailedView(failure: f),
            _ => const AppLoadingIndicator(),
          };
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

/// La cabecera del flujo no cargó: no hay snapshot que editar. NotFound
/// es terminal (sin retry).
class _PageFailedView extends StatelessWidget {
  const _PageFailedView({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is FlowsNotFoundFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          message: isNotFound
              ? 'Este flujo ya no existe en tu organización'
              : 'No pudimos cargar el flujo',
          onRetry: isNotFound
              ? null
              : () => context.read<FlowDetailBloc>().add(
                  const FlowDetailLoadRequested(),
                ),
        ),
      ),
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
  // El slider expone el cooldown en HORAS (0–120 = hasta 5 días) para
  // legibilidad humana; al guardar lo convertimos a ms. Lectura inicial: ms
  // del wire ÷ 1h redondeado. El valor inicial en horas se guarda aparte para
  // (a) el dirty-check por horas y (b) preservar el ms original EXACTO cuando
  // el operador no toca el slider — un cooldown legacy sub-hora redondea a 0h
  // pero no debe zerarse al guardar otro campo.
  late double _cooldownHours;
  late final int _initialCooldownHours;

  late final TextEditingController _usageLimitCtrl;
  late Set<String> _excludes;
  late bool _aiInvocable;

  @override
  void initState() {
    super.initState();
    _initialCooldownHours = (widget.flow.cooldownMs / kFlowSettingsMsPerHour)
        .round()
        .clamp(0, kFlowSettingsMaxCooldownHours);
    _cooldownHours = _initialCooldownHours.toDouble();
    _usageLimitCtrl = TextEditingController(
      // 0 ⇒ campo vacío para que el placeholder "Sin límite" sea visible.
      text: widget.flow.usageLimit > 0 ? widget.flow.usageLimit.toString() : '',
    );
    _usageLimitCtrl.addListener(_onUsageLimitChanged);
    _excludes = <String>{...widget.flow.excludesFlows};
    _aiInvocable = widget.flow.aiInvocable;
  }

  void _onUsageLimitChanged() {
    // El dirty-check depende del texto del field; un setState vacío basta
    // para que el botón Guardar se rebaja/habilita en cada keystroke.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _usageLimitCtrl
      ..removeListener(_onUsageLimitChanged)
      ..dispose();
    super.dispose();
  }

  // Si el operador no tocó el slider (mismas horas que al cargar), preserva el
  // ms original EXACTO (no zera un cooldown legacy sub-hora). Tocado ⇒ el valor
  // en horas manda.
  int get _cooldownMs => _cooldownHours.round() == _initialCooldownHours
      ? widget.flow.cooldownMs
      : _cooldownHours.round() * kFlowSettingsMsPerHour;

  int get _usageLimit => int.tryParse(_usageLimitCtrl.text.trim()) ?? 0;

  /// excludesFlows ordenado ASC por id antes de comparar / despachar.
  /// El orden no es semántico del dominio: ordenarlo evita PUTs no-op
  /// cuando el operador selecciona los mismos flujos en otro orden.
  List<String> get _excludesSorted {
    final out = _excludes.toList()..sort();
    return out;
  }

  bool get _isDirty {
    if (_aiInvocable != widget.flow.aiInvocable) return true;
    if (_cooldownHours.round() != _initialCooldownHours) return true;
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
        aiInvocable: _aiInvocable,
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
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.safeBottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // El guardado es explícito (a diferencia del apply-inmediato del
          // resto del editor): la línea lo hace legible antes del form.
          Text(
            'Los cambios se aplican al tocar Guardar.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp5),
          FlowSettingsAiInvocableField(
            value: _aiInvocable,
            onChanged: (v) => setState(() => _aiInvocable = v),
            textTheme: textTheme,
          ),
          const SizedBox(height: AppTokens.sp6),
          FlowSettingsCooldownField(
            hours: _cooldownHours,
            onChanged: (v) => setState(() => _cooldownHours = v),
            textTheme: textTheme,
          ),
          const SizedBox(height: AppTokens.sp6),
          FlowSettingsUsageLimitField(
            controller: _usageLimitCtrl,
            textTheme: textTheme,
          ),
          const SizedBox(height: AppTokens.sp6),
          FlowSettingsExcludesPicker(
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
            FlowSettingsFailureCopy(failure: widget.failure!),
            const SizedBox(height: AppTokens.sp4),
          ],
          if (widget.isSaving) ...<Widget>[
            const FlowSettingsSavingIndicator(),
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
