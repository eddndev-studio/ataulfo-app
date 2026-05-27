import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../../flows/presentation/bloc/flows_bloc.dart';
import '../../domain/entities/trigger.dart';
import '../bloc/triggers_bloc.dart';

/// Modal sheet de creación/edición de un Trigger.
///
/// `editing == null` ⇒ modo creación (POST /triggers); el operador
/// elige flow destino en el dropdown. `editing != null` ⇒ modo edición
/// (PUT /triggers/:id replace-completo); el flow destino es read-only
/// — el backend preserva `flowId` del trigger existente, mover un
/// trigger entre flows no está habilitado.
///
/// Discriminación por modo:
/// - TEXT: keyword + matchType + scope.
/// - LABEL: labelId + labelAction (scope no aplica en LABEL; el
///   trigger se evalúa al cambiar la SessionLabel internamente).
class TriggerEditSheet extends StatefulWidget {
  const TriggerEditSheet({super.key, this.editing});

  /// `null` ⇒ modo creación. No-null ⇒ modo edición; el sheet se
  /// pre-llena con los valores del trigger y el submit hace PUT
  /// replace-completo (no diff: ver `TriggersUpdateRequested`).
  final Trigger? editing;

  @override
  State<TriggerEditSheet> createState() => _TriggerEditSheetState();
}

class _TriggerEditSheetState extends State<TriggerEditSheet> {
  late final TextEditingController _keywordCtrl;
  late final TextEditingController _labelIdCtrl;
  late TriggerType _triggerType;
  late MatchType _matchType;
  late LabelAction _labelAction;
  late TriggerScope _scope;
  late bool _isActive;
  String? _flowId; // null hasta que el operador elija (modo create).

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _keywordCtrl = TextEditingController(text: ed?.keyword ?? '');
    _labelIdCtrl = TextEditingController(text: ed?.labelId ?? '');
    _triggerType = ed?.triggerType ?? TriggerType.text;
    _matchType = ed?.matchType ?? MatchType.exact;
    _labelAction = ed?.labelAction ?? LabelAction.add;
    _scope = ed?.scope ?? TriggerScope.both;
    _isActive = ed?.isActive ?? true;
    _flowId = ed?.flowId;
    _keywordCtrl.addListener(_onTextChanged);
    _labelIdCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _keywordCtrl.removeListener(_onTextChanged);
    _labelIdCtrl.removeListener(_onTextChanged);
    _keywordCtrl.dispose();
    _labelIdCtrl.dispose();
    super.dispose();
  }

  bool get _isText => _triggerType == TriggerType.text;
  bool get _isLabel => _triggerType == TriggerType.label;

  bool get _isSubmittable {
    if (_isText) {
      if (_keywordCtrl.text.trim().isEmpty) return false;
    } else {
      if (_labelIdCtrl.text.trim().isEmpty) return false;
    }
    // En create necesitamos un flow destino elegido.
    if (widget.editing == null && (_flowId == null || _flowId!.isEmpty)) {
      return false;
    }
    return true;
  }

  void _submit() {
    if (!_isSubmittable) return;
    final ed = widget.editing;
    if (ed == null) {
      context.read<TriggersBloc>().add(
        TriggersAddRequested(
          flowId: _flowId!,
          triggerType: _triggerType,
          matchType: _isText ? _matchType : null,
          keyword: _isText ? _keywordCtrl.text.trim() : '',
          labelId: _isLabel ? _labelIdCtrl.text.trim() : '',
          labelAction: _isLabel ? _labelAction : null,
          scope: _scope,
          isActive: _isActive,
        ),
      );
      return;
    }
    context.read<TriggersBloc>().add(
      TriggersUpdateRequested(
        triggerId: ed.id,
        triggerType: _triggerType,
        matchType: _isText ? _matchType : null,
        keyword: _isText ? _keywordCtrl.text.trim() : '',
        labelId: _isLabel ? _labelIdCtrl.text.trim() : '',
        labelAction: _isLabel ? _labelAction : null,
        scope: _scope,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<TriggersBloc, TriggersState>(
      builder: (context, state) {
        final isMutating = state is TriggersMutating;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.editing == null
                    ? 'Nuevo disparador'
                    : 'Editar disparador',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppTokens.sp4),
              _TypePicker(
                selected: _triggerType,
                enabled: !isMutating && widget.editing == null,
                onSelected: (t) => setState(() => _triggerType = t),
              ),
              const SizedBox(height: AppTokens.sp4),
              if (_isText) ...<Widget>[
                AppTextField(
                  key: const Key('trigger_edit.keyword'),
                  label: 'Palabra clave',
                  hint: 'Texto que dispara el flow',
                  controller: _keywordCtrl,
                  enabled: !isMutating,
                  autofocus: true,
                ),
                const SizedBox(height: AppTokens.sp4),
                _MatchPicker(
                  selected: _matchType,
                  enabled: !isMutating,
                  onSelected: (m) => setState(() => _matchType = m),
                ),
                const SizedBox(height: AppTokens.sp4),
                _ScopePicker(
                  selected: _scope,
                  enabled: !isMutating,
                  onSelected: (s) => setState(() => _scope = s),
                ),
              ] else ...<Widget>[
                AppTextField(
                  key: const Key('trigger_edit.label_id'),
                  label: 'Etiqueta (id)',
                  hint: 'id de la SessionLabel',
                  controller: _labelIdCtrl,
                  enabled: !isMutating,
                ),
                const SizedBox(height: AppTokens.sp4),
                _LabelActionPicker(
                  selected: _labelAction,
                  enabled: !isMutating,
                  onSelected: (a) => setState(() => _labelAction = a),
                ),
              ],
              const SizedBox(height: AppTokens.sp4),
              _FlowSelector(
                editing: widget.editing,
                selectedFlowId: _flowId,
                enabled: !isMutating,
                onSelected: (id) => setState(() => _flowId = id),
              ),
              const SizedBox(height: AppTokens.sp4),
              Row(
                key: const Key('trigger_edit.active_switch'),
                children: <Widget>[
                  Switch(
                    value: _isActive,
                    onChanged: isMutating
                        ? null
                        : (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(width: AppTokens.sp2),
                  Expanded(
                    child: Text(
                      'Activo — el disparador evalúa mensajes nuevos.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sp6),
              AppButton.filled(
                key: const Key('trigger_edit.submit'),
                label: 'Guardar',
                onPressed: _isSubmittable ? _submit : null,
                loading: isMutating,
                fullWidth: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final TriggerType selected;
  final bool enabled;
  final ValueChanged<TriggerType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('trigger_edit.type_picker'),
      spacing: 6,
      children: <Widget>[
        for (final t in TriggerType.values)
          _PickerChip(
            label: _typeLabel(t),
            selected: t == selected,
            enabled: enabled,
            onTap: () => onSelected(t),
          ),
      ],
    );
  }

  String _typeLabel(TriggerType t) => switch (t) {
    TriggerType.text => 'Texto',
    TriggerType.label => 'Etiqueta',
  };
}

class _MatchPicker extends StatelessWidget {
  const _MatchPicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final MatchType selected;
  final bool enabled;
  final ValueChanged<MatchType> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Coincidencia',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        Wrap(
          key: const Key('trigger_edit.match_picker'),
          spacing: 6,
          children: <Widget>[
            for (final m in MatchType.values)
              _PickerChip(
                label: _matchLabel(m),
                selected: m == selected,
                enabled: enabled,
                onTap: () => onSelected(m),
              ),
          ],
        ),
      ],
    );
  }

  String _matchLabel(MatchType m) => switch (m) {
    MatchType.exact => 'Exacto',
    MatchType.contains => 'Contiene',
    MatchType.regex => 'Regex',
  };
}

class _ScopePicker extends StatelessWidget {
  const _ScopePicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final TriggerScope selected;
  final bool enabled;
  final ValueChanged<TriggerScope> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Ámbito',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        Wrap(
          key: const Key('trigger_edit.scope_picker'),
          spacing: 6,
          children: <Widget>[
            for (final s in TriggerScope.values)
              _PickerChip(
                label: _scopeLabel(s),
                selected: s == selected,
                enabled: enabled,
                onTap: () => onSelected(s),
              ),
          ],
        ),
      ],
    );
  }

  String _scopeLabel(TriggerScope s) => switch (s) {
    TriggerScope.incoming => 'Entrante',
    TriggerScope.outgoing => 'Saliente',
    TriggerScope.both => 'Ambos',
  };
}

class _LabelActionPicker extends StatelessWidget {
  const _LabelActionPicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final LabelAction selected;
  final bool enabled;
  final ValueChanged<LabelAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Acción de etiqueta',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        Wrap(
          key: const Key('trigger_edit.label_action_picker'),
          spacing: 6,
          children: <Widget>[
            for (final a in LabelAction.values)
              _PickerChip(
                label: _labelActionLabel(a),
                selected: a == selected,
                enabled: enabled,
                onTap: () => onSelected(a),
              ),
          ],
        ),
      ],
    );
  }

  String _labelActionLabel(LabelAction a) => switch (a) {
    LabelAction.add => 'Agregar',
    LabelAction.remove => 'Quitar',
  };
}

/// Selector de flow destino. En modo create es un dropdown con la
/// lista del FlowsBloc del scope. En modo edit es una línea read-only
/// con el nombre del flow ("→ Flujo: <nombre>") — el backend no
/// acepta cambio de flowId en PUT (decisión nombrada), así que ni
/// siquiera pintamos un widget interactivo.
class _FlowSelector extends StatelessWidget {
  const _FlowSelector({
    required this.editing,
    required this.selectedFlowId,
    required this.enabled,
    required this.onSelected,
  });

  final Trigger? editing;
  final String? selectedFlowId;
  final bool enabled;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ed = editing;
    if (ed != null) {
      return BlocBuilder<FlowsBloc, FlowsState>(
        builder: (context, state) {
          final name = state is FlowsLoaded
              ? state.flows
                    .firstWhere(
                      (f) => f.id == ed.flowId,
                      orElse: () => fdom.Flow(
                        id: ed.flowId,
                        templateId: ed.templateId,
                        name: ed.flowId,
                        isActive: true,
                        version: 1,
                      ),
                    )
                    .name
              : ed.flowId;
          return Text(
            '→ Flujo: $name',
            key: const Key('trigger_edit.flow_readonly'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          );
        },
      );
    }
    return BlocBuilder<FlowsBloc, FlowsState>(
      builder: (context, state) {
        final textTheme = Theme.of(context).textTheme;
        final flows = state is FlowsLoaded ? state.flows : const <fdom.Flow>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Flujo destino',
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp1),
            DropdownButtonFormField<String>(
              key: const Key('trigger_edit.flow_dropdown'),
              initialValue: selectedFlowId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTokens.surface3,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp4,
                  vertical: AppTokens.sp2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusField),
                  borderSide: BorderSide.none,
                ),
              ),
              hint: const Text('Elige el flujo destino'),
              items: <DropdownMenuItem<String>>[
                for (final f in flows)
                  DropdownMenuItem<String>(value: f.id, child: Text(f.name)),
              ],
              onChanged: enabled && flows.isNotEmpty ? onSelected : null,
            ),
          ],
        );
      },
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return AppPill.primary(label: label);
    }
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: AppPill.outline(label: label),
    );
  }
}
