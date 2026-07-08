import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_section_header.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/calendar_failure.dart';
import '../bloc/booking_cubit.dart';
import '../calendar_format.dart';
import '../widgets/month_calendar_sheet.dart';

/// Reserva manual de una cita: tipo → fecha → slot → cliente → crear. Página de
/// una pushed route (aporta Scaffold+AppBar). Al crear con éxito hace pop(true)
/// para que la agenda recargue.
class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final picked = await MonthCalendarSheet.open(
      context,
      initialDate: cubit.state.date ?? DateTime.now(),
    );
    if (picked != null) await cubit.selectDate(picked);
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final failure = await cubit.book(
      customerName: _nameCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    if (failure == null) {
      navigator.pop(true);
      return;
    }
    if (failure is CalendarConflictFailure) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ese horario acaba de ocuparse. Elige otro.'),
        ),
      );
      await cubit.reloadAvailability();
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(_messageFor(failure))));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookingCubit, BookingState>(
      builder: (context, state) {
        if (state.typesStatus == BookingTypesStatus.loading) {
          return const Center(child: AppLoadingIndicator());
        }
        if (state.typesStatus == BookingTypesStatus.error) {
          return AppErrorState(
            message: 'No se pudieron cargar los tipos de cita.',
            onRetry: () => context.read<BookingCubit>().loadEventTypes(),
          );
        }
        if (state.eventTypes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTokens.sp6),
              child: Text(
                'No hay tipos de cita activos. Crea uno en Ajustes → Agenda '
                'antes de reservar.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _Form(
          state: state,
          nameCtrl: _nameCtrl,
          noteCtrl: _noteCtrl,
          onPickDate: () => _pickDate(context),
          onSubmit: () => _submit(context),
        );
      },
    );
  }

  String _messageFor(CalendarFailure failure) => switch (failure) {
    CalendarValidationFailure(:final message) =>
      message ?? 'No se pudo reservar la cita.',
    CalendarNetworkFailure() =>
      'Sin conexión. Revisa tu red e inténtalo otra vez.',
    CalendarTimeoutFailure() =>
      'La operación tardó demasiado. Inténtalo otra vez.',
    _ => 'No se pudo reservar la cita.',
  };
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.nameCtrl,
    required this.noteCtrl,
    required this.onPickDate,
    required this.onSubmit,
  });

  final BookingState state;
  final TextEditingController nameCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5,
        AppTokens.sp5 + context.safeBottomInset,
      ),
      children: <Widget>[
        const AppSectionHeader(title: 'Tipo de cita'),
        const SizedBox(height: AppTokens.sp3),
        Wrap(
          spacing: AppTokens.sp2,
          runSpacing: AppTokens.sp2,
          children: <Widget>[
            for (final et in state.eventTypes)
              AppChoiceChip(
                key: Key('booking.type.${et.id}'),
                label: '${et.name} · ${durationLabel(et.durationMin)}',
                selected: state.selectedEventType?.id == et.id,
                onSelected: (_) =>
                    context.read<BookingCubit>().selectEventType(et),
              ),
          ],
        ),
        if (state.selectedEventType != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp6),
          const AppSectionHeader(title: 'Fecha'),
          const SizedBox(height: AppTokens.sp3),
          AppButton.tonal(
            key: const Key('booking.pick_date'),
            label: state.date == null
                ? 'Elegir fecha'
                : agendaDayHeader(state.date!),
            icon: Icons.calendar_month_outlined,
            onPressed: onPickDate,
          ),
        ],
        if (state.date != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp6),
          const AppSectionHeader(title: 'Horario disponible'),
          const SizedBox(height: AppTokens.sp3),
          _Slots(state: state),
        ],
        if (state.selectedSlot != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp6),
          const AppSectionHeader(title: 'Cliente'),
          const SizedBox(height: AppTokens.sp3),
          AppTextField(
            key: const Key('booking.name'),
            label: 'Nombre del cliente',
            hint: 'Ej. Ana López',
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTokens.sp4),
          AppTextField(
            key: const Key('booking.note'),
            label: 'Nota (opcional)',
            hint: 'Motivo, referencia…',
            controller: noteCtrl,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: AppTokens.sp6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameCtrl,
            builder: (context, value, _) => AppButton.filled(
              key: const Key('booking.submit'),
              label: 'Reservar cita',
              fullWidth: true,
              loading: state.submitting,
              onPressed: value.text.trim().isEmpty || state.submitting
                  ? null
                  : onSubmit,
            ),
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Se reservará el ${agendaDayHeader(state.date!)} a las '
            '${hhmm(state.selectedSlot!.toLocal())}.',
            style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
        ],
      ],
    );
  }
}

class _Slots extends StatelessWidget {
  const _Slots({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    switch (state.slotsStatus) {
      case SlotsStatus.idle:
      case SlotsStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTokens.sp4),
          child: AppLoadingIndicator(),
        );
      case SlotsStatus.error:
        return AppErrorState(
          message: 'No se pudo cargar la disponibilidad.',
          onRetry: () => context.read<BookingCubit>().reloadAvailability(),
        );
      case SlotsStatus.loaded:
        if (state.slots.isEmpty) {
          return Text(
            'No hay horarios libres ese día. Prueba con otra fecha.',
            key: const Key('booking.no_slots'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          );
        }
        return Wrap(
          spacing: AppTokens.sp2,
          runSpacing: AppTokens.sp2,
          children: <Widget>[
            for (final slot in state.slots)
              AppChoiceChip(
                key: Key('booking.slot.${slot.toIso8601String()}'),
                label: hhmm(slot.toLocal()),
                selected: state.selectedSlot == slot,
                onSelected: (_) =>
                    context.read<BookingCubit>().selectSlot(slot),
              ),
          ],
        );
    }
  }
}
