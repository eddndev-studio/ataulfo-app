import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../bloc/triggers_bloc.dart';

/// Modal sheet de creación/edición de un Trigger. El sheet vive siempre
/// dentro del editor de un flujo concreto: `scopedFlow` es el Flow del
/// scope y fija el destino — el operador no puede mover triggers entre
/// flujos (decisión de producto + decisión del backend que preserva
/// `flowId` en PUT).
///
/// `editing == null` ⇒ modo creación (POST /triggers/:tplId/triggers)
/// con `flowId = scopedFlow.id`. `editing != null` ⇒ modo edición
/// (PUT /triggers/:id replace-completo) preservando el flowId del
/// trigger (verificado: el listado del scope solo expone triggers del
/// flow).
///
/// Discriminación por modo:
/// - TEXT: keyword + matchType + scope.
/// - LABEL: labelId + labelAction (scope no aplica en LABEL; el
///   trigger se evalúa al cambiar la SessionLabel internamente).
class TriggerEditSheet extends StatefulWidget {
  const TriggerEditSheet({super.key, required this.scopedFlow, this.editing});

  /// `null` ⇒ modo creación. No-null ⇒ modo edición; el sheet se
  /// pre-llena con los valores del trigger y el submit hace PUT
  /// replace-completo (no diff: ver `TriggersUpdateRequested`).
  final Trigger? editing;

  /// Flow del scope: fija el destino del trigger (en create) o
  /// confirma el destino (en edit). El sheet muestra su nombre en una
  /// línea informativa read-only; no consulta a `FlowsBloc`.
  final fdom.Flow scopedFlow;

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

  /// Flag que gate-a el auto-pop. El sheet escucha el estado del bloc
  /// y popea cuando llega `Loaded` post-submit; sin este gate, un
  /// `Loaded` espurio (ej. el load inicial de la sección mientras el
  /// sheet ya está montado) cerraría el sheet sin que el operador
  /// haya hecho submit. Espejo de `_didSubmit` en `StepEditSheet`.
  bool _didSubmit = false;

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
    return true;
  }

  Future<void> _confirmDelete() async {
    final ed = widget.editing;
    if (ed == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('trigger_edit.delete_confirm'),
        title: const Text('Eliminar disparador'),
        content: const Text(
          '¿Eliminar este disparador? La acción no se puede deshacer.',
        ),
        actions: <Widget>[
          AppButton.text(
            key: const Key('trigger_edit.delete_confirm.cancel'),
            label: 'Cancelar',
            onPressed: () => Navigator.of(dialogCtx).pop(false),
          ),
          AppButton.danger(
            key: const Key('trigger_edit.delete_confirm.ok'),
            label: 'Eliminar',
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    _didSubmit = true;
    context.read<TriggersBloc>().add(TriggersDeleteRequested(triggerId: ed.id));
  }

  void _submit() {
    if (!_isSubmittable) return;
    final ed = widget.editing;
    if (ed == null) {
      _didSubmit = true;
      context.read<TriggersBloc>().add(
        TriggersAddRequested(
          flowId: widget.scopedFlow.id,
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
    _didSubmit = true;
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
    return BlocListener<TriggersBloc, TriggersState>(
      listener: (context, state) {
        if (_didSubmit && state is TriggersLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<TriggersBloc, TriggersState>(
        builder: (context, state) {
          final isMutating = state is TriggersMutating;
          final failure = state is TriggersMutationFailed
              ? state.failure
              : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.sp6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.editing == null
                            ? 'Nuevo disparador'
                            : 'Editar disparador',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    if (widget.editing != null)
                      IconButton(
                        key: const Key('trigger_edit.delete'),
                        tooltip: 'Eliminar disparador',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTokens.danger,
                        ),
                        onPressed: isMutating ? null : _confirmDelete,
                      ),
                  ],
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
                _FixedFlowLine(flow: widget.scopedFlow),
                const SizedBox(height: AppTokens.sp4),
                Row(
                  key: const Key('trigger_edit.active_switch'),
                  children: <Widget>[
                    AppSwitch(
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
                if (failure != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp4),
                  _FailureCopy(
                    failure: failure,
                    isEdit: widget.editing != null,
                  ),
                ],
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
      ),
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

/// Línea informativa read-only con el nombre del flow del scope. No
/// expone control interactivo: el destino es el flow del editor, no
/// se elige ni se cambia.
class _FixedFlowLine extends StatelessWidget {
  const _FixedFlowLine({required this.flow});

  final fdom.Flow flow;

  @override
  Widget build(BuildContext context) {
    return Text(
      '→ Flujo: ${flow.name}',
      key: const Key('trigger_edit.flow_fixed'),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
    );
  }
}

/// Copy de error contextual dentro del sheet. Discrimina por failure
/// para que el operador pueda corregir y reintentar sin tener que
/// adivinar qué pasó:
/// - Invalid (422): "Revisa los datos" — caso típico (keyword vacío en
///   TEXT, regex que el guard anti-ReDoS rechazó, labelId vacío en
///   LABEL). El backend devuelve `ErrInvalidTrigger`/`ErrInvalidRegex`
///   con el mismo status; el copy es genérico.
/// - NotFound (404 en edit): "Este disparador ya no existe" — otro
///   operador lo borró entre el listado y el PUT/DELETE. La UI debe
///   forzar refresh; el sheet abierto está obsoleto.
/// - Network/Timeout: copy reintentable.
/// - El resto: copy genérico.
class _FailureCopy extends StatelessWidget {
  const _FailureCopy({required this.failure, required this.isEdit});

  final TriggersFailure failure;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    final (key, text) = _resolve();
    return Text(
      text,
      key: Key('trigger_edit.error.$key'),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppTokens.danger),
    );
  }

  (String, String) _resolve() => switch (failure) {
    TriggersInvalidFailure() => (
      'invalid',
      'Revisa los datos. Si usaste regex, asegúrate de que compile y no '
          'sea demasiado costosa.',
    ),
    TriggersNotFoundFailure() => (
      'notfound',
      isEdit
          ? 'Este disparador ya no existe. Recarga la lista para verificar.'
          : 'No encontramos la plantilla padre. Recarga la lista.',
    ),
    TriggersForbiddenFailure() => (
      'forbidden',
      'No tienes permiso para esta acción.',
    ),
    TriggersNetworkFailure() => (
      'network',
      'No pudimos conectarnos. Revisa tu red e intenta de nuevo.',
    ),
    TriggersTimeoutFailure() => (
      'timeout',
      'La operación tardó demasiado. Intenta de nuevo.',
    ),
    TriggersServerFailure() => (
      'server',
      'El servidor falló al procesar la petición. Intenta más tarde.',
    ),
    UnknownTriggersFailure() => ('unknown', 'No pudimos completar la acción.'),
  };
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
