// Archivo > 400 LOC justificado: el form CT es un solo widget cohesivo
// con tres bloques (tz selector, lista de ventanas día/hora, dropdowns
// de destino por id) que comparten estado mutable (`_EditableWindow`) y
// callback canónico (`_emit` → `onChanged(metadataJson?)`). Separar los
// sub-widgets (`_WindowBlock`, `_TimeButton`, `_TargetDropdown`) a otros
// archivos los desacoplaría del estado del padre — duplicaría callbacks
// y constructors sin mejorar cohesión.
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import 'conditional_time_day_mapping.dart';

/// Candidato a destino de una rama del condicional: el step con su
/// posición vigente y una etiqueta legible ("3. Hola, ¿en qué te ayudo?").
/// El caller (sheet) decide qué steps son candidatos válidos — al editar,
/// solo los posteriores al propio CT; al crear, todos (el CT se inserta
/// antes de sus destinos).
class CtTargetOption {
  const CtTargetOption({
    required this.id,
    required this.order,
    required this.label,
  });

  final String id;
  final int order;
  final String label;
}

/// Form del step CONDITIONAL_TIME. Edita timezone + ventanas día/hora +
/// los dos destinos de rama POR ID de step (la identidad sobrevive
/// reorders/borrados; el shape posicional murió con el rediseño).
/// Devuelve el `metadataJson` resultante vía `onChanged`: `String`
/// JSON-encoded id-form cuando la configuración es válida, `null` cuando
/// algún campo falla la validación local (días vacíos, from>=to,
/// destinos sin elegir).
///
/// `initial == null` ⇒ create con seed por default de horario (L-V
/// 09:00-18:00, `America/Mexico_City`) y SIN destinos preseleccionados —
/// elegir las ramas es decisión explícita del operador, no un default
/// que truena en runtime. `initial != null` ⇒ edit: los campos se
/// hidratan con los valores existentes; destinos que ya no estén entre
/// los candidatos quedan sin selección (el operador re-elige).
///
/// `showRecoveredWarning` pinta un aviso de que la configuración
/// original no se pudo leer (metadata corrupta o destinos irresueltos):
/// guardar REEMPLAZA la configuración anterior.
class ConditionalTimeForm extends StatefulWidget {
  const ConditionalTimeForm({
    super.key,
    required this.onChanged,
    required this.targets,
    this.initial,
    this.enabled = true,
    this.showRecoveredWarning = false,
  });

  final ValueChanged<String?> onChanged;
  final List<CtTargetOption> targets;
  final ConditionalTimeMetadata? initial;
  final bool enabled;
  final bool showRecoveredWarning;

  @override
  State<ConditionalTimeForm> createState() => _ConditionalTimeFormState();
}

/// Set v1 de timezones que el operador puede elegir. Curada y corta:
/// cubre LATAM principales + US este/oeste + España + UTC. Ampliar la
/// lista (o sustituirla por una autocomplete contra IANA) es trabajo
/// fuera de este arco — el backend acepta cualquier zona que
/// `time.LoadLocation` resuelva.
const List<String> _availableTimezones = <String>[
  'America/Mexico_City',
  'America/New_York',
  'America/Los_Angeles',
  'America/Bogota',
  'America/Buenos_Aires',
  'Europe/Madrid',
  'UTC',
];

/// Modelo mutable de una ventana mientras el operador la edita —
/// `Set<int>` de días UI (0..6, L→D), TimeOfDay para from/to. Al
/// validar se serializa a `TimeWindow` con días wire ordenados.
class _EditableWindow {
  _EditableWindow({required this.daysUi, required this.from, required this.to});

  factory _EditableWindow.fromWire(TimeWindow w) => _EditableWindow(
    daysUi: w.days.map(wireDayToUi).toSet(),
    from: _parseTimeOfDay(w.from),
    to: _parseTimeOfDay(w.to),
  );

  factory _EditableWindow.businessHours() => _EditableWindow(
    daysUi: <int>{0, 1, 2, 3, 4},
    from: const TimeOfDay(hour: 9, minute: 0),
    to: const TimeOfDay(hour: 18, minute: 0),
  );

  Set<int> daysUi;
  TimeOfDay from;
  TimeOfDay to;

  /// Intenta construir la `TimeWindow` wire. Devuelve null si la
  /// ventana es inválida (sin días o from>=to).
  TimeWindow? toWireOrNull() {
    if (daysUi.isEmpty) return null;
    final fromMin = from.hour * 60 + from.minute;
    final toMin = to.hour * 60 + to.minute;
    if (fromMin >= toMin) return null;
    final wireDays = daysUi.map(uiDayToWire).toList()..sort();
    return TimeWindow(
      days: wireDays,
      from: _formatTimeOfDay(from),
      to: _formatTimeOfDay(to),
    );
  }
}

class _ConditionalTimeFormState extends State<ConditionalTimeForm> {
  late String _tz;
  late List<_EditableWindow> _windows;
  String? _onMatchId;
  String? _onElseId;

  @override
  void initState() {
    super.initState();
    final seed = widget.initial;
    _tz = seed?.tz ?? 'America/Mexico_City';
    _windows = seed == null
        ? <_EditableWindow>[_EditableWindow.businessHours()]
        : seed.windows.map(_EditableWindow.fromWire).toList();
    // Destinos: solo se hidratan si siguen entre los candidatos vigentes
    // (un destino que dejó de ser válido aparece sin selección y el gate
    // de submit obliga a re-elegir).
    final ids = widget.targets.map((t) => t.id).toSet();
    final m = seed?.onMatchStepId;
    final e = seed?.onElseStepId;
    _onMatchId = (m != null && ids.contains(m)) ? m : null;
    _onElseId = (e != null && ids.contains(e)) ? e : null;
    // Emisión post-frame para no llamar setState durante build del
    // padre — el listener captura el estado inicial.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    final wireWindows = <TimeWindow>[];
    for (final w in _windows) {
      final ww = w.toWireOrNull();
      if (ww == null) {
        widget.onChanged(null);
        return;
      }
      wireWindows.add(ww);
    }
    if (wireWindows.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final m = _onMatchId;
    final e = _onElseId;
    if (m == null || e == null) {
      widget.onChanged(null);
      return;
    }
    final md = ConditionalTimeMetadata(
      tz: _tz,
      windows: wireWindows,
      onMatchStepId: m,
      onElseStepId: e,
    );
    widget.onChanged(md.toJsonString());
  }

  void _toggleDay(int windowIdx, int uiDay) {
    setState(() {
      final w = _windows[windowIdx];
      if (w.daysUi.contains(uiDay)) {
        w.daysUi.remove(uiDay);
      } else {
        w.daysUi.add(uiDay);
      }
    });
    _emit();
  }

  Future<void> _pickTime(int windowIdx, bool isFrom) async {
    final w = _windows[windowIdx];
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? w.from : w.to,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        w.from = picked;
      } else {
        w.to = picked;
      }
    });
    _emit();
  }

  void _addWindow() {
    setState(() {
      _windows = List<_EditableWindow>.from(_windows)
        ..add(_EditableWindow.businessHours());
    });
    _emit();
  }

  void _removeWindow(int idx) {
    if (_windows.length <= 1) return;
    setState(() {
      _windows = List<_EditableWindow>.from(_windows)..removeAt(idx);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.showRecoveredWarning) ...<Widget>[
          Container(
            key: const Key('ct_form.recovered_warning'),
            padding: const EdgeInsets.all(AppTokens.sp3),
            decoration: BoxDecoration(
              color: AppTokens.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Text(
              'La configuración guardada de este condicional no se pudo '
              'leer. Al guardar se reemplaza por la que definas aquí.',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
            ),
          ),
          const SizedBox(height: AppTokens.sp4),
        ],
        Text(
          'Zona horaria',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        DropdownButtonFormField<String>(
          key: const Key('ct_form.tz_dropdown'),
          initialValue: _availableTimezones.contains(_tz) ? _tz : null,
          isExpanded: true,
          items: _availableTimezones
              .map((z) => DropdownMenuItem<String>(value: z, child: Text(z)))
              .toList(),
          onChanged: widget.enabled
              ? (v) {
                  if (v == null) return;
                  setState(() => _tz = v);
                  _emit();
                }
              : null,
        ),
        const SizedBox(height: AppTokens.sp5),
        Text(
          'Ventanas horarias',
          style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        for (var i = 0; i < _windows.length; i++) ...<Widget>[
          _WindowBlock(
            index: i,
            window: _windows[i],
            enabled: widget.enabled,
            removable: _windows.length > 1,
            onDayToggled: (uiDay) => _toggleDay(i, uiDay),
            onPickFrom: () => _pickTime(i, true),
            onPickTo: () => _pickTime(i, false),
            onRemove: () => _removeWindow(i),
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
        AppButton.text(
          key: const Key('ct_form.add_window'),
          label: 'Agregar ventana',
          icon: Icons.add,
          onPressed: widget.enabled ? _addWindow : null,
        ),
        const SizedBox(height: AppTokens.sp5),
        Text(
          'Destinos',
          style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        Text(
          'El condicional salta al paso elegido según el horario. Una rama '
          'se cierra con un paso "Fin" — sin él, continúa con los pasos '
          'siguientes.',
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        _TargetDropdown(
          dropdownKey: const Key('ct_form.on_match_dropdown'),
          label: 'Si cumple → paso',
          targets: widget.targets,
          value: _onMatchId,
          enabled: widget.enabled,
          onChanged: (v) {
            setState(() => _onMatchId = v);
            _emit();
          },
        ),
        const SizedBox(height: AppTokens.sp3),
        _TargetDropdown(
          dropdownKey: const Key('ct_form.on_else_dropdown'),
          label: 'Si NO cumple → paso',
          targets: widget.targets,
          value: _onElseId,
          enabled: widget.enabled,
          onChanged: (v) {
            setState(() => _onElseId = v);
            _emit();
          },
        ),
      ],
    );
  }
}

class _WindowBlock extends StatelessWidget {
  const _WindowBlock({
    required this.index,
    required this.window,
    required this.enabled,
    required this.removable,
    required this.onDayToggled,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onRemove,
  });

  final int index;
  final _EditableWindow window;
  final bool enabled;
  final bool removable;
  final ValueChanged<int> onDayToggled;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
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
                  style: Theme.of(context).textTheme.labelMedium,
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
          Wrap(
            spacing: AppTokens.sp1,
            children: <Widget>[
              for (var uiDay = 0; uiDay <= 6; uiDay++)
                AppChoiceChip(
                  key: Key('ct_form.window.$index.day.$uiDay'),
                  label: uiDayLabel(uiDay),
                  selected: window.daysUi.contains(uiDay),
                  onSelected: enabled ? (_) => onDayToggled(uiDay) : null,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          Row(
            children: <Widget>[
              Expanded(
                child: _TimeButton(
                  buttonKey: Key('ct_form.window.$index.from'),
                  label: 'Desde',
                  value: window.from,
                  enabled: enabled,
                  onPressed: onPickFrom,
                ),
              ),
              const SizedBox(width: AppTokens.sp2),
              Expanded(
                child: _TimeButton(
                  buttonKey: Key('ct_form.window.$index.to'),
                  label: 'Hasta',
                  value: window.to,
                  enabled: enabled,
                  onPressed: onPickTo,
                ),
              ),
            ],
          ),
          // Una ventana inválida anula el guardado (toWireOrNull = null): el
          // motivo se explica aquí mismo, junto a los controles que lo causan.
          if (_invalidReason != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.sp2),
              child: Text(
                _invalidReason!,
                style: const TextStyle(
                  color: AppTokens.danger,
                  fontSize: AppTokens.captionSize,
                  height: AppTokens.captionLineHeight / AppTokens.captionSize,
                  fontWeight: AppTokens.captionWeight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Motivo por el que la ventana no es guardable, o null si es válida.
  /// Espeja las reglas de `_EditableWindow.toWireOrNull`.
  String? get _invalidReason {
    if (window.daysUi.isEmpty) {
      return 'Selecciona al menos un día';
    }
    final fromMin = window.from.hour * 60 + window.from.minute;
    final toMin = window.to.hour * 60 + window.to.minute;
    if (fromMin >= toMin) {
      return 'La hora de inicio debe ser anterior al final';
    }
    return null;
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.buttonKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final TimeOfDay value;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton.tonal(
      key: buttonKey,
      label: '$label  ${_formatTimeOfDay(value)}',
      onPressed: enabled ? onPressed : null,
      fullWidth: true,
    );
  }
}

class _TargetDropdown extends StatelessWidget {
  const _TargetDropdown({
    required this.dropdownKey,
    required this.label,
    required this.targets,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Key dropdownKey;
  final String label;
  final List<CtTargetOption> targets;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Sin candidatos (flow sin pasos que puedan ser destino): explicar el
    // bloqueo en lugar de un dropdown vacío que confunde.
    if (targets.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: false),
        child: const Text(
          'Agrega primero los pasos de cada rama; después configura el '
          'condicional.',
        ),
      );
    }
    final items = targets
        .map(
          (t) => DropdownMenuItem<String>(
            value: t.id,
            child: Text(
              '${t.order + 1}. ${t.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
    return DropdownButtonFormField<String>(
      key: dropdownKey,
      isExpanded: true,
      initialValue: value,
      hint: const Text('Elige un paso'),
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: enabled ? onChanged : null,
    );
  }
}

TimeOfDay _parseTimeOfDay(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _formatTimeOfDay(TimeOfDay t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
