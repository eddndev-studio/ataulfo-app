import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../calendar_format.dart';

/// Selector de fecha propio (es-MX, semana de lunes a domingo) como hoja
/// inferior. Se construye a mano en lugar de `showDatePicker` porque la app no
/// carga `flutter_localizations`: el picker de Material saldría en inglés y
/// rompería la voz del producto.
///
/// Devuelve la fecha elegida (local, sin hora) o null si se cierra sin elegir.
class MonthCalendarSheet extends StatefulWidget {
  const MonthCalendarSheet({super.key, required this.initialDate});

  final DateTime initialDate;

  static Future<DateTime?> open(
    BuildContext context, {
    required DateTime initialDate,
  }) => showAppBottomSheet<DateTime>(
    context,
    backgroundColor: AppTokens.surface1,
    isScrollControlled: true,
    builder: (_) => MonthCalendarSheet(initialDate: initialDate),
  );

  @override
  State<MonthCalendarSheet> createState() => _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends State<MonthCalendarSheet> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  void _shiftMonth(int delta) => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp4,
          AppTokens.sp2,
          AppTokens.sp4,
          AppTokens.sp4 + context.safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  key: const Key('calendar.month.prev'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    monthYearLabel(_visibleMonth),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('calendar.month.next'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.sp2),
            const _WeekdayHeader(),
            const SizedBox(height: AppTokens.sp2),
            _MonthGrid(
              month: _visibleMonth,
              selected: selected,
              today: today,
              onPick: (d) => Navigator.of(context).pop(d),
            ),
          ],
        ),
      ),
    );
  }
}

/// Letras L M X J V S D (lunes primero), en la misma convención visual que el
/// selector de días del kit.
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _labels = <String>[
    'L',
    'M',
    'X',
    'J',
    'V',
    'S',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final l in _labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: const TextStyle(
                  fontFamily: AppTokens.fontSans,
                  fontSize: AppTokens.captionSize,
                  fontWeight: AppTokens.captionWeight,
                  color: AppTokens.text2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rejilla del mes: filas de 7 celdas, lunes a domingo. Las celdas fuera del
/// mes quedan vacías (el mes vecino no es accionable desde aquí).
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.onPick,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  /// Alto fijo de cada celda: alto en vez de celdas cuadradas para que un mes
  /// de 6 semanas no desborde el alto de la hoja.
  static const double _cellHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Offset de la primera celda: lunes=0 .. domingo=6.
    final leading = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: <Widget>[
        for (var row = 0; row * 7 < totalCells; row++)
          Row(
            children: <Widget>[
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _cell(row * 7 + col - leading + 1, daysInMonth),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(int dayNum, int daysInMonth) {
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: _cellHeight);
    }
    final date = DateTime(month.year, month.month, dayNum);
    final isSelected = date == selected;
    final isToday = date == today;
    final color = isSelected ? AppTokens.onPrimary : AppTokens.text1;

    return SizedBox(
      height: _cellHeight,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: isSelected ? AppTokens.primary : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: Key('calendar.month.day.$dayNum'),
            customBorder: const CircleBorder(),
            onTap: () => onPick(date),
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontFamily: AppTokens.fontSans,
                  fontSize: AppTokens.bodyMSize,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
