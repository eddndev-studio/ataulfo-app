import 'package:flutter/material.dart';

import '../app_bottom_sheet.dart';
import '../safe_bottom.dart';
import '../tokens.dart';
import 'app_button.dart';

/// Bloques de minutos ofrecidos por la rueda: cuartos de hora.
const List<int> _quarters = <int>[0, 15, 30, 45];

/// Campo de hora del día que se edita con una RUEDA de bloques de 15 minutos,
/// no tecleando. Muestra la hora vigente como una píldora tappable (mismo
/// lenguaje que [AppSelectField]); al tocarla abre una hoja con dos ruedas
/// —hora (00–23) y minutos (00/15/30/45)— y un botón «Listo».
///
/// Widget controlado: [value] manda y cada elección confirmada emite por
/// [onChanged]. `onChanged` nulo (o [enabled] falso) lo deja deshabilitado: se
/// atenúa y el tap no abre la rueda. Pensado para horarios que «piensan en
/// bloques» de 15 minutos; un minuto fuera de la grilla se muestra tal cual y
/// se ajusta al bloque al editarse.
class AppTimeWheelField extends StatelessWidget {
  const AppTimeWheelField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = enabled && onChanged != null;
    final radius = BorderRadius.circular(AppTokens.radiusField);
    return Opacity(
      opacity: active ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp1),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: active ? () => _open(context) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Container(
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppTokens.input,
                    borderRadius: radius,
                    border: Border.all(color: AppTokens.divider, width: 2),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.sp4,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _format(value),
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTokens.text1,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.schedule,
                        size: 20,
                        color: AppTokens.text2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showAppBottomSheet<TimeOfDay>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) => _TimeWheelSheet(label: label, initial: value),
    );
    if (picked != null) onChanged?.call(picked);
  }
}

/// «HH:MM» con dos dígitos por componente.
String _format(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Bloque de 15 más cercano hacia abajo (9:07 → índice 0 = :00).
int _quarterIndexOf(int minute) => (minute ~/ 15).clamp(0, 3);

/// Hoja con las dos ruedas. El valor sólo viaja al padre al pulsar «Listo»
/// (no en cada giro): girar sin confirmar no muta el horario.
class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.label, required this.initial});

  final String label;
  final TimeOfDay initial;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const double _itemExtent = 40;

  late int _hour = widget.initial.hour;
  late int _quarterIndex = _quarterIndexOf(widget.initial.minute);
  late final FixedExtentScrollController _hourCtrl =
      FixedExtentScrollController(initialItem: _hour);
  late final FixedExtentScrollController _minCtrl = FixedExtentScrollController(
    initialItem: _quarterIndex,
  );

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(
    context,
  ).pop(TimeOfDay(hour: _hour, minute: _quarters[_quarterIndex]));

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp2,
          AppTokens.sp5,
          AppTokens.sp5 + context.sheetBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.label, style: textTheme.titleMedium),
            const SizedBox(height: AppTokens.sp4),
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Banda de selección al centro: comunica cuál fila está
                  // elegida sin depender del color del propio texto.
                  IgnorePointer(
                    child: Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        color: AppTokens.surface2,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _wheel(
                          key: const Key('time_wheel.hours'),
                          controller: _hourCtrl,
                          count: 24,
                          labelOf: (i) => i.toString().padLeft(2, '0'),
                          onSelected: (i) => _hour = i,
                        ),
                      ),
                      Text(':', style: textTheme.titleLarge),
                      Expanded(
                        child: _wheel(
                          key: const Key('time_wheel.minutes'),
                          controller: _minCtrl,
                          count: _quarters.length,
                          labelOf: (i) =>
                              _quarters[i].toString().padLeft(2, '0'),
                          onSelected: (i) => _quarterIndex = i,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.filled(
              key: const Key('time_wheel.done'),
              label: 'Listo',
              fullWidth: true,
              onPressed: _done,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) labelOf,
    required ValueChanged<int> onSelected,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return ListWheelScrollView.useDelegate(
      key: key,
      controller: controller,
      itemExtent: _itemExtent,
      physics: const FixedExtentScrollPhysics(),
      overAndUnderCenterOpacity: 0.35,
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(
          child: Text(
            labelOf(i),
            style: textTheme.titleLarge?.copyWith(color: AppTokens.text1),
          ),
        ),
      ),
    );
  }
}
