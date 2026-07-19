import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/app_inline_loading_indicator.dart';
import '../../../../core/design/widgets/app_text_action.dart';
import '../../../../core/design/widgets/voice_recording_bar.dart';
import '../../../../core/design/widgets/voice_recording_mixin.dart';
import '../../../../core/media/attachment_kind.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../../messages/presentation/widgets/attachment_tray.dart';
import '../../../messages/presentation/widgets/audio_failures_listener.dart';
import '../../domain/entities/pa_attachment.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/pa_trace.dart';
import '../bloc/platform_agent_chat_bloc.dart';
import 'pa_chat_empty_state.dart';
import 'pa_failure_copy.dart';
import 'pa_turn_group.dart';

/// Cuerpo del chat del asistente: hilo (o estado vacío con sugerencias), avisos
/// de fallo/modalidad, adjuntos pendientes y el composer —con la barra de nota
/// de voz reemplazándolo mientras se graba—. El composer es el origen del
/// borrador (que el bloc persiste por hilo); la máquina de la nota de voz vive
/// en el [VoiceRecordingMixin] compartido.
class PaChatView extends StatefulWidget {
  const PaChatView({super.key, required this.state, required this.onSend});

  final PaChatLoaded state;
  final ValueChanged<String> onSend;

  @override
  State<PaChatView> createState() => _PaChatViewState();
}

class _PaChatViewState extends State<PaChatView>
    with VoiceRecordingMixin<PaChatView> {
  /// Controller compartido: las acciones rápidas PREFIJAN el texto del composer
  /// (el operador lo edita antes de enviar) en vez de auto-enviar. También es el
  /// origen del borrador, que el bloc persiste por hilo.
  final TextEditingController _composer = TextEditingController();

  /// Bloc capturado al montar: lo usa el ciclo de la nota de voz (incluida la
  /// limpieza en dispose, cuando el context ya no es fiable).
  late final PlatformAgentChatBloc _bloc;

  @override
  void notifyVoiceStarted() => _bloc.add(const PaChatVoiceStarted());

  @override
  void notifyVoiceCancelled() {
    // También corre en la limpieza de dispose: un bloc ya cerrado no recibe.
    if (!_bloc.isClosed) _bloc.add(const PaChatVoiceCancelled());
  }

  @override
  void notifyVoiceSent(Uint8List bytes) => _bloc.add(PaChatVoiceSent(bytes));

  @override
  void initState() {
    super.initState();
    _bloc = context.read<PlatformAgentChatBloc>();
    // Al (re)montar —incl. al volver a la pestaña del shell, que destruyó el
    // composer— resembrar desde el borrador VIVO del bloc, no desde state.draft
    // (que está rancio: DraftChanged no emite). Así el texto sin enviar persiste.
    _composer.text = _bloc.activeDraft;
    _composer.addListener(_onComposerChanged);
    initVoice();
  }

  @override
  void didUpdateWidget(PaChatView old) {
    super.didUpdateWidget(old);
    final prev = old.state;
    final cur = widget.state;
    final convChanged = prev.activeConversation.id != cur.activeConversation.id;
    final failureAppeared = prev.sendFailure == null && cur.sendFailure != null;
    final cancelRestore =
        prev.sending &&
        !cur.sending &&
        cur.sendFailure == null &&
        cur.draft.isNotEmpty;
    final seedAppeared =
        prev.draft != cur.draft &&
        cur.draft.isNotEmpty &&
        _composer.text.isEmpty;
    // Sembrar el composer SOLO en transiciones puntuales: cambio de hilo o
    // cancelación restauran el borrador; un fallo recupera el texto enviado.
    // Nunca en un rebuild ordinario, para no pisar lo que el operador teclea.
    if (convChanged || cancelRestore || seedAppeared) {
      _setComposer(cur.draft);
    } else if (failureAppeared) {
      _setComposer(cur.lastAttemptedContent);
    }
  }

  void _onComposerChanged() {
    context.read<PlatformAgentChatBloc>().add(
      PaChatDraftChanged(_composer.text),
    );
  }

  void _setComposer(String text) {
    if (_composer.text == text) return;
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

  void _prefill(String text) {
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  /// La traza VIVA del turno: en vuelo va expandida, con el paso actual
  /// latiendo (cap por la cola: el paso en curso jamás se oculta) y «Detener»
  /// dentro. Sin eventos aún (el SSE no conectó) muestra un nodo «Pensando…»
  /// de arranque. Sigue montada tras el cierre del POST hasta que la recarga
  /// haga el swap; si la recarga falló queda marcada «(traza parcial)», y si
  /// el operador detuvo, colapsada al copy honesto ([traceStoppedSummary]).
  Widget _liveTrace(BuildContext context, PaChatLoaded s) {
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
      stretch: true,
      pulseLast: s.sending,
      stopped: s.liveStopped,
      onStop: s.sending
          ? () => context.read<PlatformAgentChatBloc>().add(
              const PaChatTurnCancelRequested(),
            )
          : null,
      stopButtonKey: const Key('pa.turn_cancel'),
      stoppedSummary: traceStoppedSummary,
    );
  }

  /// Memo del agrupado por turnos: [traceFromMessages] re-parsea el JSON de
  /// cada fila tool, y `build` corre por cada frame SSE del turno en vuelo —
  /// sin el memo, un hilo largo pagaría ese costo O(n) por frame en el hilo de
  /// UI. El bloc solo cambia la IDENTIDAD de `messages` cuando el hilo cambia.
  List<PaMessage>? _turnsSource;
  List<(PaTurn, Trace)> _turns = const <(PaTurn, Trace)>[];

  List<(PaTurn, Trace)> _turnsOf(List<PaMessage> messages) {
    if (!identical(_turnsSource, messages)) {
      _turnsSource = messages;
      _turns = traceFromMessages(messages);
    }
    return _turns;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final onSend = widget.onSend;
    // El hilo se agrupa por turno (gramática persistida): cada grupo es la
    // burbuja del operador, la traza del proceso y sus respuestas.
    final turns = _turnsOf(s.messages);
    // La traza viva ocupa el índice 0 mientras el turno viaja Y después del
    // cierre hasta el swap de la recarga (o anclada si quedó parcial/detenida).
    final liveVisible = s.sending || s.liveStopped || s.liveEvents.isNotEmpty;
    // El aviso de audio irreproducible cubre todo el hilo: cualquier burbuja
    // de audio sin fuente (adjunto/nota de otro dispositivo) lo dispara.
    return AudioFailuresListener(
      child: Column(
        children: <Widget>[
          Expanded(
            child: (s.messages.isEmpty && !s.sending)
                ? PaChatEmptyState(onPrefill: _prefill)
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(AppTokens.sp3),
                    itemCount:
                        turns.length +
                        (liveVisible ? 1 : 0) +
                        (s.nextCursor.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, i) {
                      // La traza VIVA en el borde inferior (índice 0 del
                      // reverse) mientras gobierne el último turno.
                      if (liveVisible && i == 0) {
                        return _liveTrace(context, s);
                      }
                      // El cargar-más vive en el tope visual (último índice del
                      // reverse), por encima del turno más viejo.
                      final base = turns.length + (liveVisible ? 1 : 0);
                      if (s.nextCursor.isNotEmpty && i == base) {
                        return _LoadMoreButton(
                          loading: s.loadingMore,
                          onTap: () => context
                              .read<PlatformAgentChatBloc>()
                              .add(const PaChatLoadMore()),
                        );
                      }
                      final idx =
                          turns.length - 1 - (i - (liveVisible ? 1 : 0));
                      final (turn, trace) = turns[idx];
                      // Mientras la traza viva gobierna el turno recién
                      // cerrado, el grupo persistido de ese turno no pinta la
                      // suya (evita el proceso duplicado). Tras un Detener la
                      // viva es de un turno que ya no existe en el hilo: los
                      // grupos conservan su traza.
                      final cede =
                          idx == turns.length - 1 &&
                          liveVisible &&
                          !s.liveStopped;
                      return PaTurnGroup(
                        key: ValueKey<String>('pa.turn.${turn.key}'),
                        turn: turn,
                        trace: trace,
                        showProcess: !cede,
                        onConfirm: s.sending
                            ? null
                            : () => onSend('Sí, confírmalo y procede.'),
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
                      platformAgentFailureCopy(s.sendFailure!),
                      key: const Key('pa.send_failure'),
                      style: const TextStyle(color: AppTokens.danger),
                    ),
                  ),
                  if (s.lastAttemptedContent.isNotEmpty)
                    AppButton.text(
                      key: const Key('pa.send_failure.retry'),
                      label: 'Reintentar',
                      // Reintentar re-despacha sin pasar por el composer; limpiarlo
                      // evita que el texto ya enviado quede y se reenvíe a mano.
                      onPressed: () {
                        _setComposer('');
                        onSend(s.lastAttemptedContent);
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
                      key: const Key('pa.modality_warning'),
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
                    (att) => _pendingAttachmentFor(
                      att,
                      s.pendingThumbnails[att.ref],
                    ),
                  )
                  .toList(growable: false),
              onRemove: (i) => context.read<PlatformAgentChatBloc>().add(
                PaChatAttachmentRemoved(s.pendingAttachments[i].ref),
              ),
            ),
          // Grabando: la barra de nota de voz reemplaza al composer (una cosa a la
          // vez). Si no, el composer con el micrófono en el slot final vacío.
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
              fieldKey: const Key('pa.composer.field'),
              sendKey: const Key('pa.composer.send'),
              hint: 'Pídele algo a tu asistente…',
              // El envío se atenúa durante la subida de adjuntos además del turno
              // en vuelo: evita la carrera adjuntar-mientras-envía.
              enabled: !s.sending && !s.attaching,
              onSend: onSend,
              // Micrófono en el slot final mientras el campo está vacío: solo si el
              // grabador está soportado y no hay adjuntos pendientes (esos se envían
              // por el flujo de texto).
              emptyTrailing: (canRecord && s.pendingAttachments.isEmpty)
                  ? IconButton(
                      key: const Key('pa.voice.mic'),
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
                  key: const Key('pa.attach'),
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
                      : () => context.read<PlatformAgentChatBloc>().add(
                          const PaChatAttachRequested(),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Botón "cargar mensajes anteriores" al tope del hilo; spinner mientras viaja.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.sp2),
        child: loading
            ? const AppInlineLoadingIndicator(size: 18)
            : AppTextAction(
                key: const Key('pa.load_more'),
                label: 'Cargar mensajes anteriores',
                onPressed: onTap,
              ),
      ),
    );
  }
}

/// Adapta un adjunto ya subido (el asistente sube al elegir, no al enviar) a
/// la bandeja compartida: [PendingAttachment.existingRef] es el ref BARE,
/// [PendingAttachment.bytes] la miniatura local ya resuelta (si la hay).
PendingAttachment _pendingAttachmentFor(PaAttachment att, Uint8List? thumb) =>
    PendingAttachment(
      bytes: thumb,
      filename: att.name,
      type: attachmentKindForMime(att.mime).name,
      existingRef: att.ref,
      sizeBytesOverride: att.sizeBytes,
    );
