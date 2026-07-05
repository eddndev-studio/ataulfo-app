import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/live_typing_progress.dart';
import '../../../../core/design/widgets/voice_recording_bar.dart';
import '../../../messages/presentation/widgets/audio_failures_listener.dart';
import '../bloc/platform_agent_chat_bloc.dart';
import 'pa_chat_empty_state.dart';
import 'pa_failure_copy.dart';
import 'pa_message_tile.dart';
import 'pa_voice_recording_mixin.dart';

/// Cuerpo del chat del asistente: hilo (o estado vacío con sugerencias), avisos
/// de fallo/modalidad, adjuntos pendientes y el composer —con la barra de nota
/// de voz reemplazándolo mientras se graba—. El composer es el origen del
/// borrador (que el bloc persiste por hilo); la máquina de la nota de voz vive
/// en [PaVoiceRecordingMixin].
class PaChatView extends StatefulWidget {
  const PaChatView({super.key, required this.state, required this.onSend});

  final PaChatLoaded state;
  final ValueChanged<String> onSend;

  @override
  State<PaChatView> createState() => _PaChatViewState();
}

class _PaChatViewState extends State<PaChatView>
    with PaVoiceRecordingMixin<PaChatView> {
  /// Controller compartido: las acciones rápidas PREFIJAN el texto del composer
  /// (el operador lo edita antes de enviar) en vez de auto-enviar. También es el
  /// origen del borrador, que el bloc persiste por hilo.
  final TextEditingController _composer = TextEditingController();

  /// Bloc capturado al montar: lo usa el ciclo de la nota de voz (incluida la
  /// limpieza en dispose, cuando el context ya no es fiable).
  late final PlatformAgentChatBloc _bloc;

  @override
  PlatformAgentChatBloc get voiceBloc => _bloc;

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
    // Sembrar el composer SOLO en transiciones puntuales: cambio de hilo o
    // cancelación restauran el borrador; un fallo recupera el texto enviado.
    // Nunca en un rebuild ordinario, para no pisar lo que el operador teclea.
    if (convChanged || cancelRestore) {
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

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final onSend = widget.onSend;
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
                        s.messages.length +
                        (s.sending ? 1 : 0) +
                        (s.nextCursor.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (s.sending && i == 0) {
                        return LiveTypingProgress(
                          label: s.liveProgress,
                          keyId: 'pa',
                        );
                      }
                      // El cargar-más vive en el tope visual (último índice del
                      // reverse), por encima del mensaje más viejo.
                      final base = s.messages.length + (s.sending ? 1 : 0);
                      if (s.nextCursor.isNotEmpty && i == base) {
                        return _LoadMoreButton(
                          loading: s.loadingMore,
                          onTap: () => context
                              .read<PlatformAgentChatBloc>()
                              .add(const PaChatLoadMore()),
                        );
                      }
                      final idx =
                          s.messages.length - 1 - (i - (s.sending ? 1 : 0));
                      return PaMessageTile(
                        message: s.messages[idx],
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
          if (s.sending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
              child: Align(
                alignment: Alignment.centerRight,
                child: AppButton.text(
                  key: const Key('pa.turn_cancel'),
                  label: 'Detener',
                  icon: Icons.stop_rounded,
                  onPressed: () => context.read<PlatformAgentChatBloc>().add(
                    const PaChatTurnCancelRequested(),
                  ),
                ),
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
          if (s.pendingAttachments.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                key: const Key('pa.pending_attachments'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
                itemCount: s.pendingAttachments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTokens.sp2),
                itemBuilder: (context, i) {
                  final att = s.pendingAttachments[i];
                  final thumb = s.pendingThumbnails[att.ref];
                  return InputChip(
                    key: Key('pa.pending_att.${att.ref}'),
                    avatar: thumb != null
                        // Miniatura real desde los bytes locales del pendiente.
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusSm,
                            ),
                            child: Image.memory(
                              thumb,
                              key: Key('pa.pending_thumb.${att.ref}'),
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              // Bytes que no decodifican caen al ícono en vez de
                              // tumbar la fila.
                              errorBuilder: (_, _, _) =>
                                  Icon(paAttachmentIcon(att.mime), size: 16),
                            ),
                          )
                        : Icon(paAttachmentIcon(att.mime), size: 16),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    label: Text(att.name, overflow: TextOverflow.ellipsis),
                    onDeleted: () => context.read<PlatformAgentChatBloc>().add(
                      PaChatAttachmentRemoved(att.ref),
                    ),
                  );
                },
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
                  tooltip: 'Adjuntar imagen o PDF',
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
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
                ),
              )
            : TextButton(
                key: const Key('pa.load_more'),
                onPressed: onTap,
                child: const Text('Cargar mensajes anteriores'),
              ),
      ),
    );
  }
}
