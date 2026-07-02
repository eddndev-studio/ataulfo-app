import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/message.dart';

/// Borrador de respuesta del hilo: el mensaje al que el operador está
/// respondiendo, o `null` si no hay respuesta en curso. Lo fija el gesto
/// "Responder" (hoja de acciones del mensaje) y lo consume el composer para
/// pintar la barra de cita y adjuntar `quotedId` al enviar. Vive en el scope del
/// hilo; se limpia al enviar o cancelar.
class ReplyDraftCubit extends Cubit<Message?> {
  ReplyDraftCubit() : super(null);

  void setReply(Message message) => emit(message);

  void clear() => emit(null);
}
