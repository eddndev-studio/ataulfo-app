import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../labels/domain/entities/label.dart';
import '../../../labels/domain/repositories/chat_labels_repository.dart';
import '../../domain/silence_labels_resolver.dart';

/// Estado de la toma del chat por el operador: ¿está el bot pausado en ESTE
/// chat (tiene una etiqueta de silencio aplicada)?
sealed class AiTakeoverState {
  const AiTakeoverState();
}

class AiTakeoverLoading extends AiTakeoverState {
  const AiTakeoverLoading();
  @override
  bool operator ==(Object other) => other is AiTakeoverLoading;
  @override
  int get hashCode => (AiTakeoverLoading).hashCode;
}

class AiTakeoverError extends AiTakeoverState {
  const AiTakeoverError();
  @override
  bool operator ==(Object other) => other is AiTakeoverError;
  @override
  int get hashCode => (AiTakeoverError).hashCode;
}

class AiTakeoverReady extends AiTakeoverState {
  const AiTakeoverReady({
    required this.silenceIds,
    required this.presentIds,
    this.busy = false,
    this.actionFailed = false,
  });

  /// Etiquetas de silencio configuradas para el bot.
  final List<String> silenceIds;

  /// De ésas, las que están aplicadas a este chat (≥1 ⇒ bot pausado aquí).
  final List<String> presentIds;

  /// Una acción (pausar/reanudar) está en curso.
  final bool busy;

  /// La última acción falló (la UI muestra el aviso; el estado no cambió).
  final bool actionFailed;

  bool get configured => silenceIds.isNotEmpty;
  bool get paused => presentIds.isNotEmpty;

  AiTakeoverReady copyWith({
    List<String>? presentIds,
    bool? busy,
    bool? actionFailed,
  }) => AiTakeoverReady(
    silenceIds: silenceIds,
    presentIds: presentIds ?? this.presentIds,
    busy: busy ?? this.busy,
    actionFailed: actionFailed ?? this.actionFailed,
  );
}

/// Cubit de la toma del chat: lee si el bot está pausado en este chat y permite
/// pausarlo/reanudarlo aplicando/quitando una etiqueta de silencio. Compone el
/// resolver de etiquetas de silencio (plantilla del bot) con el repo de
/// etiquetas por-chat; NO inventa estado nuevo (reusa el gate de runtime que ya
/// silencia por etiqueta).
class AiTakeoverCubit extends Cubit<AiTakeoverState> {
  AiTakeoverCubit({
    required SilenceLabelsResolver resolver,
    required ChatLabelsRepository chatLabels,
    required String botId,
    required String chatLid,
  }) : _resolver = resolver,
       _chatLabels = chatLabels,
       _botId = botId,
       _chatLid = chatLid,
       super(const AiTakeoverLoading());

  final SilenceLabelsResolver _resolver;
  final ChatLabelsRepository _chatLabels;
  final String _botId;
  final String _chatLid;

  Future<void> load() async {
    if (state is! AiTakeoverLoading) {
      emit(const AiTakeoverLoading());
    }
    try {
      final silenceIds = await _resolver.forBot(_botId);
      final chatLabels = await _chatLabels.listForChat(_botId, _chatLid);
      final present = chatLabels
          .where((Label l) => silenceIds.contains(l.id))
          .map((Label l) => l.id)
          .toList(growable: false);
      emit(AiTakeoverReady(silenceIds: silenceIds, presentIds: present));
    } on Object catch (_) {
      emit(const AiTakeoverError());
    }
  }

  /// Alterna la pausa del bot en este chat. Optimista pero verificable: aplica
  /// o quita la(s) etiqueta(s) de silencio y refleja el nuevo estado. Sin
  /// silencio configurado o ya ocupado ⇒ no-op.
  Future<void> toggle() async {
    final s = state;
    if (s is! AiTakeoverReady || !s.configured || s.busy) return;
    emit(s.copyWith(busy: true, actionFailed: false));
    try {
      if (s.paused) {
        for (final id in s.presentIds) {
          await _chatLabels.removeFromChat(_botId, _chatLid, id);
        }
        emit(s.copyWith(busy: false, presentIds: const <String>[]));
      } else {
        final id = s.silenceIds.first;
        await _chatLabels.addToChat(_botId, _chatLid, id);
        emit(s.copyWith(busy: false, presentIds: <String>[id]));
      }
    } on Object catch (_) {
      emit(s.copyWith(busy: false, actionFailed: true));
    }
  }
}
