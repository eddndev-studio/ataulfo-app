import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../bloc/chat_appointment_cubit.dart';
import '../calendar_format.dart';
import 'appointment_detail_sheet.dart';

/// Chip discreto en el encabezado del hilo con la PRÓXIMA cita confirmada del
/// chat. Se construye a sí mismo (provee su propio cubit) para que la ruta del
/// hilo solo lo inserte cuando el calendario está cableado. Carga perezosa y
/// silenciosa: mientras no hay cita (o si algo falla) no ocupa espacio.
class ChatAppointmentBadge extends StatelessWidget {
  const ChatAppointmentBadge({
    super.key,
    required this.repository,
    required this.botId,
    required this.chatLid,
  });

  final CalendarRepository repository;
  final String botId;
  final String chatLid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatAppointmentCubit>(
      create: (_) =>
          ChatAppointmentCubit(repository, botId: botId, chatLid: chatLid)
            ..load(),
      child: const _BadgeView(),
    );
  }
}

class _BadgeView extends StatelessWidget {
  const _BadgeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatAppointmentCubit, ChatAppointmentState>(
      builder: (context, state) {
        final next = state is ChatAppointmentLoaded ? state.next : null;
        if (next == null) return const SizedBox.shrink();
        return Material(
          color: AppTokens.surface1,
          child: InkWell(
            key: const Key('thread.appointment_badge'),
            onTap: () =>
                AppointmentDetailSheet.open(context, appointment: next),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.sp4,
                vertical: AppTokens.sp2,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTokens.divider)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.event_available,
                    size: 16,
                    color: AppTokens.primary,
                  ),
                  const SizedBox(width: AppTokens.sp2),
                  Expanded(
                    child: Text(
                      'Cita: ${nextAppointmentLabel(next.startAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTokens.fontSans,
                        fontSize: AppTokens.bodyMSize,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.text1,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTokens.text2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
