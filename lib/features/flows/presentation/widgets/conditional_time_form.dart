import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_time_range_field.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/step.dart' as fdom;
import 'conditional_time_day_mapping.dart';
import 'conditional_time_fields.dart';
import 'conditional_time_zones.dart';

/// Candidato a destino de una rama del condicional: el step con su
/// posición vigente, una etiqueta legible ("3. Hola, ¿en qué te ayudo?")
/// y su tipo (para el glifo del selector). El caller (sheet) decide qué
/// steps son candidatos válidos — al editar, solo los posteriores al
/// propio CT; al crear, todos (el CT se inserta antes de sus destinos).
class CtTargetOption {
  const CtTargetOption({
    required this.id,
    required this.order,
    required this.label,
    required this.type,
  });

  final String id;
  final int order;
  final String label;
  final fdom.StepType type;
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
///
/// `onTouched` reporta cada interacción REAL del operador con el form —
/// también cuando el resultado sigue siendo inválido (onChanged null). Es
/// la señal que le permite al guard de descarte distinguir un form
/// intocado de uno a medias; la emisión inicial post-frame no cuenta.
class ConditionalTimeForm extends StatefulWidget {
  const ConditionalTimeForm({
    super.key,
    required this.onChanged,
    required this.targets,
    this.initial,
    this.enabled = true,
    this.showRecoveredWarning = false,
    this.onTouched,
  });

  final ValueChanged<String?> onChanged;
  final List<CtTargetOption> targets;
  final ConditionalTimeMetadata? initial;
  final bool enabled;
  final bool showRecoveredWarning;
  final VoidCallback? onTouched;

  @override
  State<ConditionalTimeForm> createState() => _ConditionalTimeFormState();
}

/// Modelo mutable de una ventana mientras el operador la edita —
/// `Set<int>` de días UI (0..6, L→D) y el rango horario del kit. Al
/// validar se serializa a `TimeWindow` con días wire ordenados.
class _EditableWindow {
  _EditableWindow({required this.daysUi, required this.range});

  factory _EditableWindow.fromWire(TimeWindow w) => _EditableWindow(
    daysUi: w.days.map(wireDayToUi).toSet(),
    range: AppTimeRange(
      start: _parseTimeOfDay(w.from),
      end: _parseTimeOfDay(w.to),
    ),
  );

  factory _EditableWindow.businessHours() => _EditableWindow(
    daysUi: <int>{0, 1, 2, 3, 4},
    range: const AppTimeRange(
      start: TimeOfDay(hour: 9, minute: 0),
      end: TimeOfDay(hour: 18, minute: 0),
    ),
  );

  Set<int> daysUi;
  AppTimeRange range;

  /// Intenta construir la `TimeWindow` wire. Devuelve null si la
  /// ventana es inválida (sin días o inicio ≥ fin).
  TimeWindow? toWireOrNull() {
    if (daysUi.isEmpty) return null;
    if (!range.startBeforeEnd) return null;
    final wireDays = daysUi.map(uiDayToWire).toList()..sort();
    return TimeWindow(
      days: wireDays,
      from: _formatTimeOfDay(range.start),
      to: _formatTimeOfDay(range.end),
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

  /// Marca la interacción del operador. Solo la llaman los handlers de
  /// gestos/teclado (nunca la hidratación ni la emisión inicial), y solo
  /// cuando el gesto cambió algo de verdad — reabrir un selector y elegir
  /// lo mismo no es trabajo que proteger.
  void _touch() => widget.onTouched?.call();

  Future<void> _pickTz() async {
    final picked = await showCtTimezonePicker(context, current: _tz);
    if (picked == null || picked == _tz) return;
    _touch();
    setState(() => _tz = picked);
    _emit();
  }

  Future<void> _pickTarget({required bool isMatch}) async {
    final current = isMatch ? _onMatchId : _onElseId;
    final picked = await showCtTargetPicker(
      context,
      title: isMatch ? 'Si cumple → paso' : 'Si NO cumple → paso',
      targets: widget.targets,
      selected: current,
    );
    if (picked == null || picked == current) return;
    _touch();
    setState(() {
      if (isMatch) {
        _onMatchId = picked;
      } else {
        _onElseId = picked;
      }
    });
    _emit();
  }

  /// Etiqueta legible del destino elegido ("3. Estamos cerrados"), o null
  /// si no hay selección o el destino dejó de ser candidato.
  String? _targetLabelOf(String? id) {
    if (id == null) return null;
    for (final t in widget.targets) {
      if (t.id == id) return '${t.order + 1}. ${t.label}';
    }
    return null;
  }

  /// Posición 1-based ante la que se insertará el CT nuevo (su destino más
  /// temprano), o null cuando el caption no aplica. Solo al CREAR: el alta
  /// inserta el condicional antes de sus destinos (espeja la posición que
  /// viaja en el evento de alta); al editar no hay re-inserción. El form
  /// distingue creación porque solo ahí llega sin config inicial NI aviso
  /// de recuperación.
  int? get _insertBeforePosition {
    final isCreate = widget.initial == null && !widget.showRecoveredWarning;
    if (!isCreate) return null;
    final m = _onMatchId;
    final e = _onElseId;
    if (m == null || e == null) return null;
    int? min;
    for (final t in widget.targets) {
      if (t.id != m && t.id != e) continue;
      if (min == null || t.order < min) min = t.order;
    }
    return min == null ? null : min + 1;
  }

  void _setDays(int windowIdx, Set<int> daysUi) {
    _touch();
    setState(() => _windows[windowIdx].daysUi = daysUi);
    _emit();
  }

  void _setRange(int windowIdx, AppTimeRange range) {
    if (range == _windows[windowIdx].range) return;
    _touch();
    setState(() => _windows[windowIdx].range = range);
    _emit();
  }

  void _addWindow() {
    _touch();
    setState(() {
      _windows = List<_EditableWindow>.from(_windows)
        ..add(_EditableWindow.businessHours());
    });
    _emit();
  }

  void _removeWindow(int idx) {
    if (_windows.length <= 1) return;
    _touch();
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
        CtSheetField(
          key: const Key('ct_form.tz_dropdown'),
          label: 'Zona horaria',
          // Nombre humano para el set curado; una tz válida fuera del set
          // (escrita por otro cliente) se muestra con su id IANA crudo —
          // nunca un campo vacío que aparenta no tener configuración.
          value: ctTimezoneLabel(_tz),
          enabled: widget.enabled,
          onTap: _pickTz,
        ),
        const SizedBox(height: AppTokens.sp5),
        Text(
          'Ventanas horarias',
          style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        for (var i = 0; i < _windows.length; i++) ...<Widget>[
          CtWindowBlock(
            index: i,
            daysUi: _windows[i].daysUi,
            range: _windows[i].range,
            enabled: widget.enabled,
            removable: _windows.length > 1,
            onDaysChanged: (days) => _setDays(i, days),
            onRangeChanged: (range) => _setRange(i, range),
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
        // Sin candidatos (flow sin pasos que puedan ser destino): explicar
        // el bloqueo en lugar de un selector vacío que confunde.
        if (widget.targets.isEmpty)
          Text(
            'Agrega primero los pasos de cada rama; después configura el '
            'condicional.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTokens.text2,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...<Widget>[
          CtSheetField(
            key: const Key('ct_form.on_match_dropdown'),
            label: 'Si cumple → paso',
            value: _targetLabelOf(_onMatchId),
            hint: 'Elige un paso',
            enabled: widget.enabled,
            onTap: () => _pickTarget(isMatch: true),
          ),
          const SizedBox(height: AppTokens.sp3),
          CtSheetField(
            key: const Key('ct_form.on_else_dropdown'),
            label: 'Si NO cumple → paso',
            value: _targetLabelOf(_onElseId),
            hint: 'Elige un paso',
            enabled: widget.enabled,
            onTap: () => _pickTarget(isMatch: false),
          ),
          // El caption vivo mata la auto-inserción sorpresa: la posición
          // donde aparecerá el condicional se anuncia ANTES de guardar.
          if (_insertBeforePosition != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Este condicional se insertará antes del paso '
              '$_insertBeforePosition.',
              key: const Key('ct_form.insert_position'),
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
          ],
        ],
      ],
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
