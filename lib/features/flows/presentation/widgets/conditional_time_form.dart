// Archivo > 400 LOC justificado: el form CT es un solo widget cohesivo
// con tres bloques (tz selector, lista de ventanas día/hora, dropdowns
// onMatch/onElse) que comparten estado mutable (`_EditableWindow`) y
// callback canónico (`_emit` → `onChanged(metadataJson?)`). Separar los
// sub-widgets (`_WindowBlock`, `_TimeButton`, `_OrderDropdown`) a otros
// archivos los desacoplaría del estado del padre — duplicaría callbacks
// y constructors sin mejorar cohesión. Cuando aterrice una segunda
// representación (ej. preview gráfico de la ventana semanal) el split
// será natural; hoy no aporta.
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import 'conditional_time_day_mapping.dart';

/// Form del step CONDITIONAL_TIME. Edita timezone + ventanas día/hora +
/// los dos `order` destino (match/else). Devuelve el `metadataJson`
/// resultante vía `onChanged`: `String` JSON-encoded cuando la
/// configuración es válida, `null` cuando algún campo falla la
/// validación local (días vacíos, from>=to, etc.).
///
/// El form NO conoce al sheet ni al bloc — recibe `availableStepOrders`
/// (los `order` válidos para los dropdowns destino) como input. El
/// caller decide si excluye o no el step actual de esa lista.
///
/// `initial == null` ⇒ create con seed por default (L-V 09:00-18:00,
/// `America/Mexico_City`, onMatch=0, onElse=1). `initial != null` ⇒
/// edit, los campos se hidratan con los valores existentes.
class ConditionalTimeForm extends StatefulWidget {
  const ConditionalTimeForm({
    super.key,
    required this.onChanged,
    required this.availableStepOrders,
    this.initial,
    this.enabled = true,
  });

  final ValueChanged<String?> onChanged;
  final List<int> availableStepOrders;
  final ConditionalTimeMetadata? initial;
  final bool enabled;

  @override
  State<ConditionalTimeForm> createState() => _ConditionalTimeFormState();
}

/// Set v1 de timezones que el operador puede elegir. Curada y corta:
/// cubre LATAM principales + US este/oeste + España + UTC. Ampliar la
/// lista (o sustituirla por una autocomplete contra IANA) es trabajo
/// fuera del arco del editor base — el backend acepta cualquier zona
/// que `time.LoadLocation` resuelva.
const List<String> _availableTimezones = <String>[
  'America/Mexico_City',
  'America/New_York',
  'America/Los_Angeles',
  'America/Bogota',
  'America/Buenos_Aires',
  'Europe/Madrid',
  'UTC',
];

/// Seed default L-V 09:00-18:00 (business hours estándar). El operador
/// ajusta o submitea como está.
const ConditionalTimeMetadata _defaultSeed = ConditionalTimeMetadata(
  tz: 'America/Mexico_City',
  windows: <TimeWindow>[
    TimeWindow(days: <int>[1, 2, 3, 4, 5], from: '09:00', to: '18:00'),
  ],
  onMatchOrder: 0,
  onElseOrder: 1,
);

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
  late int _onMatch;
  late int _onElse;

  @override
  void initState() {
    super.initState();
    final seed = widget.initial ?? _defaultSeed;
    _tz = seed.tz;
    _windows = seed.windows.map(_EditableWindow.fromWire).toList();
    _onMatch = seed.onMatchOrder;
    _onElse = seed.onElseOrder;
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
    if (_onMatch < 0 || _onElse < 0) {
      widget.onChanged(null);
      return;
    }
    final md = ConditionalTimeMetadata(
      tz: _tz,
      windows: wireWindows,
      onMatchOrder: _onMatch,
      onElseOrder: _onElse,
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
        ..add(
          _EditableWindow(
            daysUi: <int>{0, 1, 2, 3, 4},
            from: const TimeOfDay(hour: 9, minute: 0),
            to: const TimeOfDay(hour: 18, minute: 0),
          ),
        );
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
        Text(
          'Zona horaria',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        DropdownButtonFormField<String>(
          key: const Key('ct_form.tz_dropdown'),
          initialValue: _tz,
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
        TextButton.icon(
          key: const Key('ct_form.add_window'),
          onPressed: widget.enabled ? _addWindow : null,
          icon: const Icon(Icons.add),
          label: const Text('Agregar ventana'),
        ),
        const SizedBox(height: AppTokens.sp5),
        Text(
          'Destinos',
          style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        _OrderDropdown(
          dropdownKey: const Key('ct_form.on_match_dropdown'),
          label: 'Si cumple → paso',
          orders: widget.availableStepOrders,
          value: _onMatch,
          enabled: widget.enabled && widget.availableStepOrders.isNotEmpty,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _onMatch = v);
            _emit();
          },
        ),
        const SizedBox(height: AppTokens.sp3),
        _OrderDropdown(
          dropdownKey: const Key('ct_form.on_else_dropdown'),
          label: 'Si NO cumple → paso',
          orders: widget.availableStepOrders,
          value: _onElse,
          enabled: widget.enabled && widget.availableStepOrders.isNotEmpty,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _onElse = v);
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
                FilterChip(
                  key: Key('ct_form.window.$index.day.$uiDay'),
                  label: Text(uiDayLabel(uiDay)),
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
        ],
      ),
    );
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
    return OutlinedButton(
      key: buttonKey,
      onPressed: enabled ? onPressed : null,
      child: Text('$label  ${_formatTimeOfDay(value)}'),
    );
  }
}

class _OrderDropdown extends StatelessWidget {
  const _OrderDropdown({
    required this.dropdownKey,
    required this.label,
    required this.orders,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Key dropdownKey;
  final String label;
  final List<int> orders;
  final int value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Sin opciones (flow con sólo el CT): mantener el valor como display
    // text deshabilitado. El operador agregará destinos después.
    if (orders.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: false),
        child: const Text('Sin pasos destino disponibles'),
      );
    }
    final items = orders
        .map(
          (o) => DropdownMenuItem<int>(value: o, child: Text('Paso #${o + 1}')),
        )
        .toList();
    // Si `value` no aparece en la lista (ej. seed default 0/1 con flow
    // de un solo step), agregamos un item virtual para no crashear al
    // construir el dropdown. El operador puede elegir un valor real al
    // tocar el dropdown.
    final hasValue = orders.contains(value);
    return DropdownButtonFormField<int>(
      key: dropdownKey,
      isExpanded: true,
      initialValue: hasValue ? value : orders.first,
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
