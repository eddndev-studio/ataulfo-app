import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/appointment.dart';
import '../calendar_format.dart';

/// Cápsula del estado de una cita, teñida por estado. Sigue el lenguaje del
/// [AppChoiceChip] seleccionado (fondo del color al 16% + borde y label del
/// color), pero con la paleta específica del ciclo de la cita, que el kit no
/// cubre con una sola variante:
/// - Confirmada → marca (primary)
/// - Cancelada  → gris (text2)
/// - Completada → éxito (teal)
/// - No asistió → aviso (naranja)
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final AppointmentStatus status;

  Color get _color => switch (status) {
    AppointmentStatus.confirmed => AppTokens.primary,
    AppointmentStatus.cancelled => AppTokens.text2,
    AppointmentStatus.completed => AppTokens.success,
    AppointmentStatus.noShow => AppTokens.warning,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color),
      ),
      child: Text(
        appointmentStatusLabel(status),
        style: const TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: AppTokens.captionSize,
          fontWeight: AppTokens.captionWeight,
        ).copyWith(color: color),
      ),
    );
  }
}
