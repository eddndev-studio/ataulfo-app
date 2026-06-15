import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/label.dart';
import '../../domain/failures/labels_failure.dart';
import '../../domain/repositories/chat_labels_repository.dart';

/// Bloc de SOLO LECTURA de los Labels INTERNOS puestos a UN chat: las etiquetas
/// org-scoped que aplican el operador, los flujos y el agente IA sobre esta
/// conversación. Vive atado a la sección "Internas" del sheet de etiquetas, que
/// las muestra junto a la sección WhatsApp (`WaChatLabelsBloc`).
///
/// Por qué solo lectura: aplicar/quitar una etiqueta interna desde el cliente
/// va por el path del operador, que dispara flujos por trigger de etiqueta y NO
/// se refleja en WhatsApp aunque la etiqueta esté mapeada. Mostrarlas (incluidas
/// las que pone la IA, antes invisibles en el cliente) cumple el objetivo de
/// distinguir internas de WhatsApp sin ese efecto secundario; el toggle interno
/// queda como trabajo posterior.
///
/// `loadMappedLabelIds` es best-effort: devuelve los ids de Label interno
/// mapeados a una etiqueta WhatsApp (para anotar "también en WhatsApp"). Si falla
/// (p. ej. el bot no tiene mapeos), la sección se pinta sin la anotación — nunca
/// tumba la carga. Sin realtime: el sheet siempre carga fresco al abrir.
class ChatLabelsBloc extends Bloc<ChatLabelsEvent, ChatLabelsState> {
  ChatLabelsBloc({
    required ChatLabelsRepository chatRepo,
    required String botId,
    required String chatLid,
    Future<Set<String>> Function()? loadMappedLabelIds,
  }) : _chat = chatRepo,
       _botId = botId,
       _chatLid = chatLid,
       _loadMapped = loadMappedLabelIds,
       super(const ChatLabelsLoading()) {
    on<ChatLabelsLoadRequested>(_onLoad);
  }

  final ChatLabelsRepository _chat;
  final String _botId;
  final String _chatLid;
  final Future<Set<String>> Function()? _loadMapped;

  Future<void> _onLoad(
    ChatLabelsLoadRequested event,
    Emitter<ChatLabelsState> emit,
  ) async {
    if (state is! ChatLabelsLoading) {
      emit(const ChatLabelsLoading());
    }
    try {
      final applied = await _chat.listForChat(_botId, _chatLid);
      // best-effort: la anotación "también en WhatsApp" no debe tumbar la carga.
      var mapped = const <String>{};
      final loadMapped = _loadMapped;
      if (loadMapped != null) {
        try {
          mapped = await loadMapped();
        } on Object {
          mapped = const <String>{};
        }
      }
      emit(ChatLabelsLoaded(applied: applied, mapped: mapped));
    } on LabelsFailure catch (f) {
      emit(ChatLabelsFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class ChatLabelsEvent {
  const ChatLabelsEvent();
}

class ChatLabelsLoadRequested extends ChatLabelsEvent {
  const ChatLabelsLoadRequested();
  @override
  bool operator ==(Object other) => other is ChatLabelsLoadRequested;
  @override
  int get hashCode => (ChatLabelsLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class ChatLabelsState {
  const ChatLabelsState();
}

class ChatLabelsLoading extends ChatLabelsState {
  const ChatLabelsLoading();
  @override
  bool operator ==(Object other) => other is ChatLabelsLoading;
  @override
  int get hashCode => (ChatLabelsLoading).hashCode;
}

class ChatLabelsLoaded extends ChatLabelsState {
  const ChatLabelsLoaded({required this.applied, required this.mapped});

  /// Labels internos PUESTOS al chat (no el catálogo): lo que está aplicado.
  final List<Label> applied;

  /// Ids (de `applied`) que están mapeados a una etiqueta WhatsApp.
  final Set<String> mapped;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChatLabelsLoaded) return false;
    return _listEq(other.applied, applied) && _setEq(other.mapped, mapped);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(applied), Object.hashAllUnordered(mapped));
}

class ChatLabelsFailed extends ChatLabelsState {
  const ChatLabelsFailed(this.failure);

  final LabelsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ChatLabelsFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}

bool _listEq(List<Label> a, List<Label> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEq(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
