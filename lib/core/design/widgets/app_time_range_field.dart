import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'app_text_field.dart';

/// Rango horario dentro de un mismo día: inicio y fin como [TimeOfDay].
///
/// Valor inmutable con igualdad estructural, pensado para widgets
/// controlados. [startBeforeEnd] es estricto: un rango colapsado
/// (inicio == fin) describe una ventana vacía y cuenta como desordenado.
@immutable
class AppTimeRange {
  const AppTimeRange({required this.start, required this.end});

  final TimeOfDay start;
  final TimeOfDay end;

  /// `true` si el inicio es estrictamente anterior al fin dentro del día.
  bool get startBeforeEnd =>
      start.hour * 60 + start.minute < end.hour * 60 + end.minute;

  @override
  bool operator ==(Object other) =>
      other is AppTimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'AppTimeRange($start – $end)';
}

/// Rango horario editable del design system: dos campos hh:mm del kit
/// ([AppTextField]) lado a lado — nada de diálogos de reloj de Material.
///
/// Widget controlado: [value] manda, cada edición interpretable emite por
/// [onChanged] y el consumer decide el nuevo valor. Un texto que no
/// interpreta como hora («9:», «25:00») marca SU campo con «Usa hh:mm» y no
/// emite; el último valor bueno sigue vigente.
///
/// **Contrato de orden y medianoche.** Con [requireStartBeforeEnd] (default)
/// el campo exige inicio estrictamente anterior al fin dentro del mismo día
/// y muestra el motivo cuando no se cumple — espeja el contrato de las
/// ventanas horarias del wire, donde cada ventana vive dentro de un día y un
/// horario que cruza medianoche (22:00–02:00) se modela como DOS ventanas
/// (22:00–23:59 y 00:00–02:00). El aviso no secuestra el estado: el rango
/// desordenado se emite igual y el guardado lo gatea el consumer. Un dominio
/// que sí interprete el cruce de medianoche como envolvente puede apagar la
/// regla con `requireStartBeforeEnd: false`.
class AppTimeRangeField extends StatefulWidget {
  const AppTimeRangeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.requireStartBeforeEnd = true,
    this.startLabel = 'Desde',
    this.endLabel = 'Hasta',
    this.keyPrefix = 'app_time_range_field',
  });

  final AppTimeRange value;

  /// Recibe el rango tras cada edición interpretable (aunque esté
  /// desordenado). Null ⇒ campos deshabilitados.
  final ValueChanged<AppTimeRange>? onChanged;

  /// Exigir inicio < fin (ver contrato de medianoche en la clase).
  final bool requireStartBeforeEnd;

  final String startLabel;
  final String endLabel;

  /// Prefijo de las keys de los campos (`<keyPrefix>.start` / `.end`).
  final String keyPrefix;

  @override
  State<AppTimeRangeField> createState() => _AppTimeRangeFieldState();
}

class _AppTimeRangeFieldState extends State<AppTimeRangeField> {
  late final TextEditingController _startController = TextEditingController(
    text: _format(widget.value.start),
  );
  late final TextEditingController _endController = TextEditingController(
    text: _format(widget.value.end),
  );

  @override
  void didUpdateWidget(AppTimeRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronía con el valor externo SIN pisar lo tecleado: solo se reescribe
    // el texto cuando ya no interpreta al valor vigente (cambio real desde
    // afuera). El eco del propio onChanged interpreta igual y se deja intacto
    // — reescribirlo a la forma canónica movería el caret en plena edición.
    if (_parse(_startController.text) != widget.value.start) {
      _startController.text = _format(widget.value.start);
    }
    if (_parse(_endController.text) != widget.value.end) {
      _endController.text = _format(widget.value.end);
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onEdited(String text, {required bool isStart}) {
    final parsed = _parse(text);
    // El rebuild refresca las marcas de error derivadas de los textos.
    setState(() {});
    if (parsed == null) return;
    widget.onChanged?.call(
      isStart
          ? AppTimeRange(start: parsed, end: widget.value.end)
          : AppTimeRange(start: widget.value.start, end: parsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final start = _parse(_startController.text);
    final end = _parse(_endController.text);

    // El aviso de orden solo habla cuando AMBOS textos interpretan: mientras
    // un campo esté marcado con «Usa hh:mm», ese es el único mensaje visible.
    final showOrderError =
        widget.requireStartBeforeEnd &&
        start != null &&
        end != null &&
        !AppTimeRange(start: start, end: end).startBeforeEnd;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _timeField(
                key: Key('${widget.keyPrefix}.start'),
                label: widget.startLabel,
                controller: _startController,
                error: start == null,
                enabled: enabled,
                isStart: true,
              ),
            ),
            const SizedBox(width: AppTokens.sp2),
            Expanded(
              child: _timeField(
                key: Key('${widget.keyPrefix}.end'),
                label: widget.endLabel,
                controller: _endController,
                error: end == null,
                enabled: enabled,
                isStart: false,
              ),
            ),
          ],
        ),
        if (showOrderError) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(
            'La hora de inicio debe ser anterior al final',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTokens.danger),
          ),
        ],
      ],
    );
  }

  Widget _timeField({
    required Key key,
    required String label,
    required TextEditingController controller,
    required bool error,
    required bool enabled,
    required bool isStart,
  }) {
    return AppTextField(
      key: key,
      label: label,
      hint: 'hh:mm',
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.datetime,
      autocorrect: false,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
        LengthLimitingTextInputFormatter(5),
      ],
      errorText: error ? 'Usa hh:mm' : null,
      onChanged: (text) => _onEdited(text, isStart: isStart),
    );
  }
}

/// «H:MM» o «HH:MM» → [TimeOfDay]; null si el texto no es una hora del día.
TimeOfDay? _parse(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Forma canónica de escritura: dos dígitos por componente («09:05»).
String _format(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
