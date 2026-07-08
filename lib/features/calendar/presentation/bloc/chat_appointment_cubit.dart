import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/appointment.dart';
import '../../domain/failures/calendar_failure.dart';
import '../../domain/repositories/calendar_repository.dart';

/// Badge de cita en el hilo del chat: la próxima cita CONFIRMADA y FUTURA
/// ligada a este chat, o nada. Carga perezosa y SILENCIOSA — si algo falla, el
/// badge simplemente no aparece (nunca molesta al operador con un error en el
/// encabezado del chat).
///
/// Por eso no hay estado de error: cualquier falla degrada a [hidden]. El
/// estado [loaded] con `next == null` también se pinta como nada; la distinción
/// existe para que la UI sepa que ya se consultó.
sealed class ChatAppointmentState {
  const ChatAppointmentState();
}

class ChatAppointmentHidden extends ChatAppointmentState {
  const ChatAppointmentHidden();
}

class ChatAppointmentLoaded extends ChatAppointmentState {
  const ChatAppointmentLoaded(this.next);

  /// Próxima cita confirmada y futura, o null si no hay ninguna.
  final Appointment? next;
}

class ChatAppointmentCubit extends Cubit<ChatAppointmentState> {
  ChatAppointmentCubit(
    this._repo, {
    required this.botId,
    required this.chatLid,
    DateTime? clock,
  }) : _clock = clock,
       super(const ChatAppointmentHidden());

  final CalendarRepository _repo;
  final String botId;
  final String chatLid;
  final DateTime? _clock;

  /// Consulta las citas del chat y expone la más próxima confirmada y futura.
  Future<void> load() async {
    try {
      final appts = await _repo.appointmentsByChat(
        botId: botId,
        chatLid: chatLid,
      );
      emit(ChatAppointmentLoaded(_pickNext(appts)));
    } on CalendarFailure {
      emit(const ChatAppointmentHidden());
    }
  }

  Appointment? _pickNext(List<Appointment> appts) {
    final now = _clock ?? DateTime.now();
    final upcoming =
        appts
            .where(
              (a) =>
                  a.status == AppointmentStatus.confirmed &&
                  a.startAt.toUtc().isAfter(now.toUtc()),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
