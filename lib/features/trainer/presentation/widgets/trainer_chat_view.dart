import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/voice_recording_bar.dart';
import '../../../../core/design/widgets/voice_recording_mixin.dart';
import '../../../../core/media/attachment_kind.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../../messages/presentation/widgets/attachment_tray.dart';
import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/trainer_trace.dart';
import '../bloc/trainer_chat_bloc.dart';
import 'trainer_chat_empty_state.dart';
import 'trainer_failure_copy.dart';
import 'trainer_turn_group.dart';

/// Cuerpo del chat del entrenador: hilo agrupado por turnos (o estado vacío
/// con sugerencias), la traza viva del turno en vuelo, avisos de
/// fallo/modalidad, adjuntos pendientes y el composer —con la barra de nota de
/// voz reemplazándolo mientras se graba—. El composer es el origen del
/// borrador (que el bloc persiste por hilo); la máquina de la nota de voz vive
/// en el [VoiceRecordingMixin] compartido.
class TrainerChatView extends StatefulWidget {
  const TrainerChatView({super.key, required this.state});

  final TrainerChatLoaded state;

  @override
  State<TrainerChatView> createState() => _TrainerChatViewState();
}

class _TrainerChatViewState extends State<TrainerChatView>
    with VoiceRecordingMixin<TrainerChatView> {
  /// Controller externo: es el origen del borrador (que el bloc persiste por
  /// hilo) y permite re-sembrar el composer al cambiar de hilo, fallar o cancelar.
  final TextEditingController _composer = TextEditingController();

  /// Bloc capturado al montar: lo usa el ciclo de la nota de voz (incluida la
  /// limpieza en dispose, cuando el context ya no es fiable).
  late final TrainerChatBloc _bloc;

  @override
  void notifyVoiceStarted() => _bloc.add(const TrainerChatVoiceStarted());

  @override
  void notifyVoiceCancelled() {
    // También corre en la limpieza de dispose: un bloc ya cerrado no recibe.
    if (!_bloc.isClosed) _bloc.add(const TrainerChatVoiceCancelled());
  }

  @override
  void notifyVoiceSent(Uint8List bytes) =>
      _bloc.add(TrainerChatVoiceSent(bytes));

  @override
  void initState() {
    super.initState();
    _bloc = context.read<TrainerChatBloc>();
    _composer.text = widget.state.draft;
    _composer.addListener(_onComposerChanged);
    initVoice();
  }

  @override
  void didUpdateWidget(TrainerChatView old) {
    super.didUpdateWidget(old);
    final prev = old.state;
    final cur = widget.state;
    final convChanged = prev.conversation.id != cur.conversation.id;
    final failureAppeared = prev.sendFailure == null && cur.sendFailure != null;
    final cancelRestore =
        prev.sending &&
        !cur.sending &&
        cur.sendFailure == null &&
        cur.draft.isNotEmpty;
    // Sembrar el composer SOLO en transiciones puntuales (cambio de hilo o
    // cancelación restauran el borrador; un fallo recupera el texto enviado),
    // nunca en un rebuild ordinario, para no pisar lo que el operador teclea.
    if (convChanged || cancelRestore) {
      _setComposer(cur.draft);
    } else if (failureAppeared) {
      _setComposer(cur.lastAttemptedContent);
    }
  }

  void _onComposerChanged() {
    context.read<TrainerChatBloc>().add(
      TrainerChatDraftChanged(_composer.text),
    );
  }

  void _setComposer(String text) {
    if (_composer.text == text) return;
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  void _prefill(String text) {
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  void dispose() {
    disposeVoice();
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    super.dispose();
  }

  void _send(String text) {
    // No enviar con un lote de adjuntos a medio subir: cerraría el turno con
    // un subconjunto y perdería en silencio los que aún suben.
    if (widget.state.sending || widget.state.attaching) return;
    context.read<TrainerChatBloc>().add(TrainerChatMessageSent(text));
  }

  /// La traza VIVA del turno: en vuelo va expandida, con el paso actual
  /// latiendo (cap por la cola: el paso en curso jamás se oculta) y «Detener»
  /// dentro. Sin eventos aún (el SSE no conectó) muestra un nodo «Pensando…»
  /// de arranque. Sigue montada tras el cierre del POST hasta que la recarga
  /// haga el swap; si la recarga falló queda marcada «(traza parcial)», y si
  /// el operador detuvo, colapsada al copy honesto ([traceStoppedSummary]).
  Widget _liveTrace(BuildContext context, TrainerChatLoaded s) {
    final live = liveTrace(s.liveEvents, parcial: s.livePartial);
    final empty = live.nodos.isEmpty;
    final resumen = empty ? 'Pensando…' : summarizeTrace(live);
    return TraceTimeline(
      nodes: empty
          ? const <TraceNode>[
              TraceNode(
                kind: TraceNodeKind.thinking,
                titulo: 'Pensando…',
                icon: Icons.psychology_outlined,
              ),
            ]
          : capNodesLive(live.nodos),
      summary: s.livePartial ? '$resumen (traza parcial)' : resumen,
      initiallyExpanded: true,
      pulseLast: s.sending,
      stopped: s.liveStopped,
      onStop: s.sending
          ? () => context.read<TrainerChatBloc>().add(
              const TrainerChatTurnCancelRequested(),
            )
          : null,
      stopButtonKey: const Key('trainer.turn_cancel'),
      stoppedSummary: traceStoppedSummary,
    );
  }

  /// Memo del agrupado por turnos: [traceFromMessages] re-parsea el JSON de
  /// cada fila tool, y `build` corre por cada frame SSE del turno en vuelo —
  /// sin el memo, un hilo largo pagaría ese costo O(n) por frame en el hilo de
  /// UI. El bloc solo cambia la IDENTIDAD de `messages` cuando el hilo cambia.
  List<TrainerMessage>? _turnsSource;
  List<(TrainerTurn, Trace)> _turns = const <(TrainerTurn, Trace)>[];

  List<(TrainerTurn, Trace)> _turnsOf(List<TrainerMessage> messages) {
    if (!identical(_turnsSource, messages)) {
      _turnsSource = messages;
      _turns = traceFromMessages(messages);
    }
    return _turns;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    // El hilo se agrupa por turno (gramática persistida): cada grupo es la
    // burbuja del operador, la traza del proceso y sus respuestas.
    final turns = _turnsOf(s.messages);
    // La traza viva ocupa el índice 0 mientras el turno viaja Y después del
    // cierre hasta el swap de la recarga (o anclada si quedó parcial/detenida).
    final liveVisible = s.sending || s.liveStopped || s.liveEvents.isNotEmpty;
    return Column(
      children: <Widget>[
        Expanded(
          // Hilo vacío en reposo: el área del chat quedaría en blanco, así que
          // la ocupa el estado vacío con sus sugerencias de arranque.
          child: (s.messages.isEmpty && !s.sending)
              ? TrainerChatEmptyState(onPrefill: _prefill)
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppTokens.sp3),
                  itemCount: turns.length + (liveVisible ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (liveVisible && i == 0) {
                      return _liveTrace(context, s);
                    }
                    final idx = turns.length - 1 - (i - (liveVisible ? 1 : 0));
                    final (turn, trace) = turns[idx];
                    // Mientras la traza viva gobierna el turno recién cerrado,
                    // el grupo persistido de ese turno no pinta la suya (evita
                    // el proceso duplicado). Tras un Detener la viva es de un
                    // turno que ya no existe en el hilo: los grupos conservan
                    // su traza.
                    final cede =
                        idx == turns.length - 1 &&
                        liveVisible &&
                        !s.liveStopped;
                    return TrainerTurnGroup(
                      key: ValueKey<String>('trainer.turn.${turn.key}'),
                      turn: turn,
                      trace: trace,
                      showProcess: !cede,
                    );
                  },
                ),
        ),
        if (s.sendFailure != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp3,
              vertical: AppTokens.sp1,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    trainerFailureCopy(s.sendFailure!),
                    key: const Key('trainer.send_failure'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
                  ),
                ),
                if (s.lastAttemptedContent.isNotEmpty)
                  AppButton.text(
                    key: const Key('trainer.send_failure.retry'),
                    label: 'Reintentar',
                    // Reintentar re-despacha sin pasar por el composer; limpiarlo
                    // evita que el texto ya enviado quede y se reenvíe a mano.
                    onPressed: () {
                      _setComposer('');
                      _send(s.lastAttemptedContent);
                    },
                  ),
              ],
            ),
          ),
        if (s.modalityWarning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp3,
              vertical: AppTokens.sp1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp1),
                Flexible(
                  child: Text(
                    s.modalityWarning,
                    key: const Key('trainer.modality_warning'),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                  ),
                ),
              ],
            ),
          ),
        // Misma bandeja de adjuntos pendientes que el chat de clientes: tarjetas
        // cuadradas con miniatura real (no el chip angosto con nombre de antes).
        if (s.pendingAttachments.isNotEmpty)
          AttachmentTray(
            items: s.pendingAttachments
                .map(
                  (att) =>
                      _pendingAttachmentFor(att, s.pendingThumbnails[att.ref]),
                )
                .toList(growable: false),
            onRemove: (i) => context.read<TrainerChatBloc>().add(
              TrainerChatAttachmentRemoved(s.pendingAttachments[i].ref),
            ),
          ),
        // Grabando: la barra de nota de voz reemplaza al composer (una cosa a
        // la vez). Si no, el composer con el micrófono en el slot final vacío.
        if (s.recordingVoice && recorder != null)
          VoiceRecordingBar(
            elapsed: recorder!.elapsed,
            amplitude: recorder!.amplitude,
            onCancel: cancelVoice,
            onSend: sendVoice,
            onPauseResume: togglePauseVoice,
            paused: paused,
            sending: sendingVoice,
          )
        else
          AppChatComposer(
            controller: _composer,
            fieldKey: const Key('trainer.composer.field'),
            sendKey: const Key('trainer.composer.send'),
            hint: 'Cuéntale de tu negocio…',
            // El envío se atenúa durante la subida de adjuntos además del turno
            // en vuelo: evita la carrera adjuntar-mientras-envía.
            enabled: !s.sending && !s.attaching,
            onSend: _send,
            // Micrófono en el slot final mientras el campo está vacío: solo si
            // el grabador está soportado y no hay adjuntos pendientes (esos se
            // envían por el flujo de texto).
            emptyTrailing: (canRecord && s.pendingAttachments.isEmpty)
                ? IconButton(
                    key: const Key('trainer.voice.mic'),
                    tooltip: 'Grabar nota de voz',
                    icon: const Icon(
                      Icons.mic_none_outlined,
                      color: AppTokens.text2,
                    ),
                    onPressed: startVoice,
                  )
                : null,
            leading: <Widget>[
              IconButton(
                key: const Key('trainer.attach'),
                tooltip: 'Adjuntar imagen, video o PDF',
                icon: s.attaching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file, color: AppTokens.text2),
                onPressed: s.attaching || s.sending
                    ? null
                    : () => context.read<TrainerChatBloc>().add(
                        const TrainerChatAttachRequested(),
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Adapta un adjunto ya subido (el entrenador sube al elegir, no al enviar) a
/// la bandeja compartida: [PendingAttachment.existingRef] es el ref BARE,
/// [PendingAttachment.bytes] la miniatura local ya resuelta (si la hay).
PendingAttachment _pendingAttachmentFor(
  TrainerAttachment att,
  Uint8List? thumb,
) => PendingAttachment(
  bytes: thumb,
  filename: att.name,
  type: attachmentKindForMime(att.mime).name,
  existingRef: att.ref,
  sizeBytesOverride: att.sizeBytes,
);
