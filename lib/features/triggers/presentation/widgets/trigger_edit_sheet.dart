import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../flows/domain/entities/flow.dart' as fdom;
import '../../../labels/domain/entities/label.dart';
import '../../../labels/presentation/bloc/labels_bloc.dart';
import '../../../labels/presentation/widgets/label_dot.dart';
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

  /// Id de la `SessionLabel` elegida en el selector (modo LABEL). `null`
  /// ⇒ sin selección (en creación el submit queda bloqueado). En edición
  /// se hidrata con el `labelId` del trigger; si ese id ya no está en el
  /// catálogo, el selector lo muestra como "etiqueta desconocida" pero
  /// el valor se preserva para no perder lo que el operador tenía.
  String? _selectedLabelId;
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
    _selectedLabelId = (ed != null && ed.labelId.trim().isNotEmpty)
        ? ed.labelId
        : null;
    _triggerType = ed?.triggerType ?? TriggerType.text;
    _matchType = ed?.matchType ?? MatchType.exact;
    _labelAction = ed?.labelAction ?? LabelAction.add;
    _scope = ed?.scope ?? TriggerScope.both;
    _isActive = ed?.isActive ?? true;
    _keywordCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _keywordCtrl.removeListener(_onTextChanged);
    _keywordCtrl.dispose();
    super.dispose();
  }

  bool get _isText => _triggerType == TriggerType.text;
  bool get _isLabel => _triggerType == TriggerType.label;

  bool get _isSubmittable {
    if (_isText) {
      if (_keywordCtrl.text.trim().isEmpty) return false;
    } else {
      // LABEL exige una etiqueta elegida — no se crea un trigger LABEL
      // sin label. En edición el valor viene hidratado; en creación el
      // operador debe elegir uno del selector.
      final id = _selectedLabelId;
      if (id == null || id.trim().isEmpty) return false;
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
          labelId: _isLabel ? (_selectedLabelId?.trim() ?? '') : '',
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
        labelId: _isLabel ? (_selectedLabelId?.trim() ?? '') : '',
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
                  _LabelPicker(
                    selectedLabelId: _selectedLabelId,
                    enabled: !isMutating,
                    onSelected: (id) => setState(() => _selectedLabelId = id),
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

/// Selector de la etiqueta interna sobre la que dispara el trigger LABEL.
/// Lee el catálogo (`LabelsBloc`, org-scoped) y deja elegir por nombre +
/// color, en vez de teclear el id. El `labelId` que produce es el id de
/// la `SessionLabel` — exactamente lo que el backend evalúa al cambiar la
/// etiqueta internamente (sea por acción manual o por una etiqueta de
/// WhatsApp mapeada).
///
/// El estado de carga vive en el bloc, no aquí: el picker dibuja
/// loading / error+reintento / vacío / lista según el estado. Un fallo
/// cargando el catálogo solo afecta a este selector — un trigger TEXT no
/// lo consume y queda intacto.
class _LabelPicker extends StatelessWidget {
  const _LabelPicker({
    required this.selectedLabelId,
    required this.enabled,
    required this.onSelected,
  });

  /// Id elegido (o hidratado en edición). `null` ⇒ sin selección.
  final String? selectedLabelId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const Key('trigger_edit.label_picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Etiqueta',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        BlocBuilder<LabelsBloc, LabelsState>(
          builder: (context, state) => switch (state) {
            LabelsLoading() => const Padding(
              key: Key('trigger_edit.label_picker.loading'),
              padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            LabelsFailed() => _ErrorRetry(enabled: enabled),
            LabelsLoaded(labels: final ls) => _LabelOptions(
              labels: ls,
              selectedLabelId: selectedLabelId,
              enabled: enabled,
              onSelected: onSelected,
            ),
          },
        ),
      ],
    );
  }
}

/// Error + reintento del catálogo. El reintento redispatcha la carga al
/// `LabelsBloc`; el resto del sheet (acción de etiqueta, activo) sigue
/// operable.
class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('trigger_edit.label_picker.error'),
      children: <Widget>[
        const Expanded(
          child: Text(
            'No pudimos cargar las etiquetas.',
            style: TextStyle(color: AppTokens.danger),
          ),
        ),
        AppButton.text(
          key: const Key('trigger_edit.label_picker.retry'),
          label: 'Reintentar',
          onPressed: enabled
              ? () =>
                    context.read<LabelsBloc>().add(const LabelsLoadRequested())
              : null,
        ),
      ],
    );
  }
}

/// Lista seleccionable del catálogo. Si el id vigente no está en el
/// catálogo (label borrado o desconocido), antepone una fila
/// "desconocida" con el id crudo para no descartarlo en silencio. Si el
/// catálogo está vacío y no hay nada seleccionado, muestra el empty
/// state que invita a crear una etiqueta primero.
class _LabelOptions extends StatelessWidget {
  const _LabelOptions({
    required this.labels,
    required this.selectedLabelId,
    required this.enabled,
    required this.onSelected,
  });

  final List<Label> labels;
  final String? selectedLabelId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedId = selectedLabelId?.trim();
    final hasSelection = selectedId != null && selectedId.isNotEmpty;
    final isKnown = hasSelection && labels.any((l) => l.id == selectedId);

    if (labels.isEmpty && !hasSelection) {
      return Text(
        'Aún no hay etiquetas. Crea una primero en la sección de etiquetas.',
        key: const Key('trigger_edit.label_picker.empty'),
        style: textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.text2,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasSelection && !isKnown) _UnknownOption(rawId: selectedId),
        for (final l in labels)
          _LabelOptionTile(
            label: l,
            selected: l.id == selectedId,
            enabled: enabled,
            onTap: () => onSelected(l.id),
          ),
      ],
    );
  }
}

class _LabelOptionTile extends StatelessWidget {
  const _LabelOptionTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Label label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('trigger_edit.label_picker.option.${label.id}'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.sp2,
          horizontal: AppTokens.sp1,
        ),
        child: Row(
          children: <Widget>[
            LabelDot(hex: label.color),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: Text(
                label.name,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                key: Key('trigger_edit.label_picker.selected'),
                color: AppTokens.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila para un id que ya no está en el catálogo. No se descarta en
/// silencio: muestra el id crudo para que el operador vea qué tenía y
/// decida si lo reemplaza por una etiqueta vigente.
class _UnknownOption extends StatelessWidget {
  const _UnknownOption({required this.rawId});

  final String rawId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('trigger_edit.label_picker.unknown'),
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sp2,
        horizontal: AppTokens.sp1,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.help_outline, color: AppTokens.text2, size: 16),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Etiqueta desconocida',
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
                Text(
                  rawId,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTokens.text2,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const <String>[
                      'RobotoMono',
                      'Courier',
                      'monospace',
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            key: Key('trigger_edit.label_picker.selected'),
            color: AppTokens.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
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
