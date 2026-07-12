import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/failures/calendar_failure.dart';
import '../calendar_format.dart';
import 'appointment_status_chip.dart';

/// Detalle de una cita como hoja inferior: datos completos y, sobre una cita
/// CONFIRMADA, las acciones de cierre (Cancelar / Completar / No asistió).
/// Cancelar pide confirmación antes de aplicar.
///
/// [onStatusChange] aplica la transición y devuelve la falla o null; la hoja
/// se queda abierta y muestra el error si falla, y se cierra al tener éxito.
/// Null ⇒ el detalle es solo lectura (sin acciones). [onOpenChat] pinta el
/// atajo al hilo cuando la cita nació de un chat.
class AppointmentDetailSheet extends StatefulWidget {
  const AppointmentDetailSheet({
    super.key,
    required this.appointment,
    this.onStatusChange,
    this.onOpenChat,
  });

  final Appointment appointment;
  final Future<CalendarFailure?> Function(AppointmentStatus status)?
  onStatusChange;
  final VoidCallback? onOpenChat;

  static Future<void> open(
    BuildContext context, {
    required Appointment appointment,
    Future<CalendarFailure?> Function(AppointmentStatus status)? onStatusChange,
    VoidCallback? onOpenChat,
  }) => showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    isScrollControlled: true,
    builder: (_) => AppointmentDetailSheet(
      appointment: appointment,
      onStatusChange: onStatusChange,
      onOpenChat: onOpenChat,
    ),
  );

  @override
  State<AppointmentDetailSheet> createState() => _AppointmentDetailSheetState();
}

class _AppointmentDetailSheetState extends State<AppointmentDetailSheet> {
  bool _busy = false;
  String? _error;

  Appointment get _a => widget.appointment;

  Future<void> _apply(AppointmentStatus status) async {
    final change = widget.onStatusChange;
    if (change == null || _busy) return;
    if (status == AppointmentStatus.cancelled) {
      final ok = await showAppConfirmDialog(
        context,
        title: '¿Cancelar esta cita?',
        message:
            'La cita queda cancelada y su horario se libera. No se puede '
            'deshacer.',
        confirmLabel: 'Cancelar cita',
        cancelLabel: 'Volver',
        confirmKey: const Key('agenda.detail.cancel_confirm'),
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await change(status);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _messageFor(failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final localDay = _a.startAt.toLocal();
    final canAct =
        widget.onStatusChange != null &&
        _a.status == AppointmentStatus.confirmed;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp2,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(_a.eventTypeName, style: textTheme.titleLarge),
                ),
                const SizedBox(width: AppTokens.sp2),
                AppointmentStatusChip(status: _a.status),
              ],
            ),
            const SizedBox(height: AppTokens.sp4),
            _Field(
              icon: Icons.event_outlined,
              label: 'Cuándo',
              value:
                  '${agendaDayHeader(DateTime(localDay.year, localDay.month, localDay.day))}'
                  ' · ${localTimeRange(_a.startAt, _a.endAt)}',
            ),
            _Field(
              icon: Icons.person_outline,
              label: 'Cliente',
              value: _a.customerName.isEmpty ? 'Sin nombre' : _a.customerName,
            ),
            if (_a.note.trim().isNotEmpty)
              _Field(
                icon: Icons.sticky_note_2_outlined,
                label: 'Nota',
                value: _a.note,
              ),
            _Field(
              icon: _a.createdBy == AppointmentCreatedBy.ai
                  ? Icons.auto_awesome
                  : Icons.badge_outlined,
              label: 'Creada por',
              value: _a.createdBy == AppointmentCreatedBy.ai
                  ? 'El asistente'
                  : 'Un operador',
            ),
            if (widget.onOpenChat != null && _a.hasChat) ...<Widget>[
              const SizedBox(height: AppTokens.sp2),
              AppButton.text(
                key: const Key('agenda.detail.open_chat'),
                label: 'Ver conversación',
                icon: Icons.chat_bubble_outline,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenChat!.call();
                },
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              Text(
                _error!,
                key: const Key('agenda.detail.error'),
                style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
              ),
            ],
            if (canAct) ...<Widget>[
              const SizedBox(height: AppTokens.sp5),
              AppButton.filled(
                key: const Key('agenda.detail.complete'),
                label: 'Marcar completada',
                fullWidth: true,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _apply(AppointmentStatus.completed),
              ),
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                key: const Key('agenda.detail.no_show'),
                label: 'No asistió',
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => _apply(AppointmentStatus.noShow),
              ),
              const SizedBox(height: AppTokens.sp3),
              AppButton.danger(
                key: const Key('agenda.detail.cancel'),
                label: 'Cancelar cita',
                fullWidth: true,
                onPressed: _busy
                    ? null
                    : () => _apply(AppointmentStatus.cancelled),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _messageFor(CalendarFailure failure) => switch (failure) {
    CalendarValidationFailure(:final message) =>
      message ?? 'No se pudo aplicar el cambio.',
    CalendarNetworkFailure() =>
      'Sin conexión. Revisa tu red e inténtalo otra vez.',
    CalendarTimeoutFailure() =>
      'La operación tardó demasiado. Inténtalo otra vez.',
    CalendarNotFoundFailure() => 'La cita ya no existe.',
    CalendarForbiddenFailure() => 'No tienes permiso para esta acción.',
    CalendarPlanRequiredFailure() =>
      'Tu plan no incluye la agenda. Mejora tu plan para usarla.',
    _ => 'No se pudo aplicar el cambio.',
  };
}

/// Fila etiqueta+valor con ícono del detalle.
class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sp3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppTokens.text2),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
                ),
                const SizedBox(height: 2),
                Text(value, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
