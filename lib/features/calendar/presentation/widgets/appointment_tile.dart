import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/appointment.dart';
import '../calendar_format.dart';
import 'appointment_status_chip.dart';

/// Fila de una cita en la agenda del día: hora local (inicio–fin), tipo de
/// evento, cliente, el chip de estado y un badge «IA» cuando la reservó el
/// asistente. Una cita cancelada se atenúa y tacha el título para leerse como
/// baja de un vistazo. Tocar abre el detalle.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final a = appointment;
    final cancelled = a.status == AppointmentStatus.cancelled;
    final dim = cancelled ? 0.5 : 1.0;

    return AppCard(
      key: Key('agenda.appointment.${a.id}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Columna de hora: el dato de escaneo primario de una agenda.
          SizedBox(
            width: 96,
            child: Opacity(
              opacity: dim,
              child: Text(
                localTimeRange(a.startAt, a.endAt),
                style: textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Opacity(
                        opacity: dim,
                        child: Text(
                          a.eventTypeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            decoration: cancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (a.createdBy == AppointmentCreatedBy.ai) ...<Widget>[
                      const SizedBox(width: AppTokens.sp2),
                      const _AiBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Opacity(
                  opacity: dim,
                  child: Text(
                    a.customerName.isEmpty ? 'Sin nombre' : a.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sp2),
                AppointmentStatusChip(status: a.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marca discreta de autoría del asistente.
class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTokens.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 12, color: AppTokens.primary),
          SizedBox(width: 4),
          Text(
            'IA',
            style: TextStyle(
              fontFamily: AppTokens.fontSans,
              fontSize: AppTokens.captionSize,
              fontWeight: AppTokens.captionWeight,
              color: AppTokens.primary,
            ),
          ),
        ],
      ),
    );
  }
}
