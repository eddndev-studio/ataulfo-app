import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_day_chips.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_switch.dart';
import '../../../../core/design/widgets/app_time_wheel_field.dart';
import '../../domain/entities/business_hours.dart';
import '../../domain/failures/calendar_failure.dart';
import '../bloc/business_hours_cubit.dart';
import '../calendar_format.dart';

/// Días en orden visual español (lunes primero), como índices de wire
/// (0=domingo..6=sábado): lunes=1 … domingo=0.
const List<int> _visualOrder = <int>[1, 2, 3, 4, 5, 6, 0];

/// Ajustes → Agenda → Horario de atención: editor semanal. Por día, una lista
/// de tramos [abre, cierra]; agregar/quitar tramo y copiar el horario de un día
/// a otros. Guardar hace un PUT de reemplazo total.
class BusinessHoursPage extends StatelessWidget {
  const BusinessHoursPage({super.key});

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<BusinessHoursCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final failure = await cubit.save();
    if (failure == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Horario guardado.')),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(_messageFor(failure))));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BusinessHoursCubit, BusinessHoursState>(
      builder: (context, state) {
        return switch (state.status) {
          BusinessHoursStatus.loading => const Center(
            child: AppLoadingIndicator(),
          ),
          BusinessHoursStatus.error => AppErrorState(
            message: 'No se pudo cargar el horario.',
            onRetry: () => context.read<BusinessHoursCubit>().load(),
          ),
          BusinessHoursStatus.loaded => _Editor(
            state: state,
            onSave: () => _save(context),
          ),
        };
      },
    );
  }

  static String _messageFor(CalendarFailure failure) => switch (failure) {
    CalendarValidationFailure(:final message) =>
      message ?? 'Hay tramos que se cruzan. Revísalos.',
    CalendarForbiddenFailure() => 'No tienes permiso para esta acción.',
    CalendarPlanRequiredFailure() =>
      'Tu plan no incluye la agenda. Mejora tu plan para usarla.',
    CalendarNetworkFailure() =>
      'Sin conexión. Revisa tu red e inténtalo otra vez.',
    _ => 'No se pudo guardar. Inténtalo otra vez.',
  };
}

class _Editor extends StatelessWidget {
  const _Editor({required this.state, required this.onSave});

  final BusinessHoursState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.sp5,
              AppTokens.sp5,
              AppTokens.sp5,
              AppTokens.sp5,
            ),
            children: <Widget>[
              for (final weekday in _visualOrder) ...<Widget>[
                _DayCard(weekday: weekday, slots: state.slotsFor(weekday)),
                const SizedBox(height: AppTokens.sp4),
              ],
              if (!state.isValid)
                Text(
                  'Hay tramos que se cruzan o con la hora de cierre antes de la '
                  'apertura. Corrígelos para guardar.',
                  key: const Key('hours.invalid'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTokens.danger),
                ),
            ],
          ),
        ),
        _SaveBar(canSave: state.canSave, saving: state.saving, onSave: onSave),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.weekday, required this.slots});

  final int weekday;
  final List<BusinessHoursSlot> slots;

  Future<void> _copyTo(BuildContext context) async {
    final cubit = context.read<BusinessHoursCubit>();
    final targets = await _CopyDaySheet.open(context, from: weekday);
    if (targets != null && targets.isNotEmpty) {
      cubit.copyDay(weekday, targets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<BusinessHoursCubit>();
    final name = weekdayFull(weekday);
    final open = slots.isNotEmpty;
    return AppCard(
      key: Key('hours.day.$weekday'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${name[0].toUpperCase()}${name.substring(1)}',
                  style: textTheme.titleMedium,
                ),
              ),
              if (open)
                IconButton(
                  key: Key('hours.copy.$weekday'),
                  tooltip: 'Copiar a otros días',
                  icon: const Icon(Icons.copy_all_outlined, size: 20),
                  onPressed: () => _copyTo(context),
                ),
              // El toggle abre (tramo por defecto) o cierra (limpia el día) sin
              // que el operador tenga que agregar/quitar tramos a mano.
              AppSwitch(
                key: Key('hours.toggle.$weekday'),
                value: open,
                onChanged: (v) =>
                    v ? cubit.addSlot(weekday) : cubit.clearDay(weekday),
              ),
            ],
          ),
          // Los días cerrados se colapsan a la fila del toggle: nada de campos
          // que estiren la lista y obliguen a un scroll largo.
          if (!open)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.sp1),
              child: Text(
                'Cerrado',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            )
          else ...<Widget>[
            for (var i = 0; i < slots.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.sp3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: AppTimeWheelField(
                        key: Key('hours.open.$weekday.$i'),
                        label: 'Desde',
                        value: _timeOf(slots[i].openMin),
                        onChanged: (t) => cubit.updateSlotAt(
                          weekday,
                          i,
                          openMin: _minutes(t),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.sp2),
                    Expanded(
                      child: AppTimeWheelField(
                        key: Key('hours.close.$weekday.$i'),
                        label: 'Hasta',
                        value: _timeOf(slots[i].closeMin),
                        onChanged: (t) => cubit.updateSlotAt(
                          weekday,
                          i,
                          closeMin: _minutes(t),
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('hours.remove.$weekday.$i'),
                      tooltip: 'Quitar tramo',
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppTokens.danger,
                      ),
                      onPressed: () => cubit.removeSlotAt(weekday, i),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTokens.sp2),
            AppButton.text(
              key: Key('hours.add.$weekday'),
              label: 'Agregar tramo',
              icon: Icons.add,
              onPressed: () => cubit.addSlot(weekday),
            ),
          ],
        ],
      ),
    );
  }

  static TimeOfDay _timeOf(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
}

/// Barra inferior con «Guardar», deshabilitada si no hay cambios válidos.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.canSave,
    required this.saving,
    required this.onSave,
  });

  final bool canSave;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp5,
        AppTokens.sp3,
        AppTokens.sp5,
        AppTokens.sp3 + context.safeBottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(top: BorderSide(color: AppTokens.divider)),
      ),
      child: AppButton.filled(
        key: const Key('hours.save'),
        label: 'Guardar horario',
        fullWidth: true,
        loading: saving,
        onPressed: canSave ? onSave : null,
      ),
    );
  }
}

/// Hoja para elegir a qué días copiar el horario, con el selector de días del
/// kit (índices de UI, lunes primero). Devuelve los días destino como índices
/// de WIRE (0=domingo..6=sábado), excluyendo el origen.
class _CopyDaySheet extends StatefulWidget {
  const _CopyDaySheet({required this.from});

  final int from;

  static Future<Set<int>?> open(BuildContext context, {required int from}) =>
      showAppBottomSheet<Set<int>>(
        context,
        backgroundColor: AppTokens.surface1,
        builder: (_) => _CopyDaySheet(from: from),
      );

  @override
  State<_CopyDaySheet> createState() => _CopyDaySheetState();
}

class _CopyDaySheetState extends State<_CopyDaySheet> {
  final Set<int> _uiSelected = <int>{};

  /// UI (0=lunes..6=domingo) → wire (0=domingo..6=sábado).
  static int _uiToWire(int ui) => (ui + 1) % 7;
  static int _wireToUi(int wire) => (wire + 6) % 7;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fromUi = _wireToUi(widget.from);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp4,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Copiar el horario de ${weekdayFull(widget.from)} a:',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.sp4),
            AppDayChips(
              keyPrefix: 'hours.copy_targets',
              selected: _uiSelected,
              onChanged: (next) => setState(() {
                _uiSelected
                  ..clear()
                  ..addAll(next.where((d) => d != fromUi));
              }),
            ),
            const SizedBox(height: AppTokens.sp5),
            AppButton.filled(
              key: const Key('hours.copy_apply'),
              label: 'Copiar',
              fullWidth: true,
              onPressed: _uiSelected.isEmpty
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(_uiSelected.map(_uiToWire).toSet()),
            ),
          ],
        ),
      ),
    );
  }
}
