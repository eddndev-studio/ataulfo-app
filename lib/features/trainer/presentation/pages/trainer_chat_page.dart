import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_thread_list_sheet.dart';
import '../../../../core/design/widgets/live_typing_progress.dart';
import '../../../../core/design/widgets/voice_recording_bar.dart';
import '../../../../core/design/widgets/voice_recording_mixin.dart';
import '../../../messages/presentation/widgets/audio_failures_listener.dart';
import '../../domain/failures/trainer_failure.dart';
import '../bloc/trainer_chat_bloc.dart';
import '../widgets/trainer_chat_empty_state.dart';
import '../widgets/trainer_message_tile.dart';
import '../widgets/trainer_model_menu.dart';

/// Chat con el agente entrenador de la plantilla. El turno es síncrono:
/// mientras viaja se muestra typing y el composer queda bloqueado. Los
/// mensajes tool con resultados de escritura (edit_prompt/write_doc/
/// edit_doc/delete_doc) se proyectan como tarjetas de cambio.
class TrainerChatPage extends StatelessWidget {
  const TrainerChatPage({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenador'),
        actions: <Widget>[
          const TrainerModelMenu(),
          IconButton(
            key: const Key('trainer.workspace'),
            tooltip: 'Workspace del negocio',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () =>
                context.push('/templates/$templateId/trainer/workspace'),
          ),
          IconButton(
            key: const Key('trainer.preview'),
            tooltip: 'Probar bot',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () =>
                context.push('/templates/$templateId/trainer/preview'),
          ),
          IconButton(
            key: const Key('trainer.threads'),
            tooltip: 'Conversaciones',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => _showThreads(context),
          ),
          IconButton(
            key: const Key('trainer.new_conversation'),
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => context.read<TrainerChatBloc>().add(
              const TrainerChatNewConversationRequested(),
            ),
          ),
        ],
      ),
      // El aviso de audio irreproducible cubre todo el hilo: cualquier burbuja
      // de audio sin fuente (adjunto de otro dispositivo) lo dispara.
      body: AudioFailuresListener(
        child: BlocBuilder<TrainerChatBloc, TrainerChatState>(
          builder: (context, state) => switch (state) {
            TrainerChatLoading() => const AppLoadingIndicator(),
            TrainerChatFailed(:final failure) => _FailedView(failure: failure),
            TrainerChatLoaded() => _ChatView(state: state),
          },
        ),
      ),
    );
  }

  /// Abre el selector de hilos compartido. Sin menú por hilo: el entrenador no
  /// expone renombrar/eliminar conversaciones. Tocar un hilo lo activa y cierra
  /// el cajón.
  void _showThreads(BuildContext context) {
    final bloc = context.read<TrainerChatBloc>();
    final state = bloc.state;
    if (state is! TrainerChatLoaded) return;
    showAppBottomSheet<void>(
      context,
      builder: (sheetCtx) => AppThreadListSheet(
        keyPrefix: 'trainer.threads',
        title: 'Conversaciones',
        activeId: state.conversation.id,
        items: <AppThreadListItem>[
          for (final c in state.conversations)
            AppThreadListItem(id: c.id, title: c.title),
        ],
        onSelect: (id) {
          Navigator.of(sheetCtx).pop();
          bloc.add(TrainerChatConversationSelected(id));
        },
      ),
    );
  }
}

/// Copy por tipo de fallo, compartido por las tres pantallas del entrenador.
String trainerFailureCopy(TrainerFailure f) => switch (f) {
  TrainerEngineFailure() =>
    'El motor IA no pudo completar el turno. Intenta de nuevo.',
  TrainerUnavailableFailure() =>
    'Esta capacidad no está habilitada en el servidor.',
  TrainerConflictFailure() =>
    'Otro editor (el panel o el entrenador) cambió esto al mismo tiempo. Recarga e intenta de nuevo.',
  TrainerValidationFailure() =>
    'El contenido no pasó las reglas (revisa nombre/tamaño).',
  TrainerAttachmentTooLargeFailure() =>
    'El archivo pesa demasiado (máx 25 MB).',
  TrainerAttachmentUnsupportedFailure() =>
    'Tipo no soportado (imagen JPG/PNG/WebP, video MP4 o PDF).',
  TrainerAttachmentLimitFailure() =>
    'Puedes adjuntar hasta 5 archivos por turno.',
  TrainerNotFoundFailure() => 'Eso ya no existe.',
  TrainerForbiddenFailure() => 'Necesitas rol ADMIN para esto.',
  TrainerNetworkFailure() => 'Sin conexión con el servidor.',
  TrainerTimeoutFailure() => 'La operación tardó demasiado.',
  TrainerServerFailure() => 'Error del servidor. Intenta más tarde.',
  TrainerUnknownFailure() => 'Algo salió mal.',
};

/// Fallo de la carga inicial: copy por tipo sobre el estado de error del kit.
class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TrainerFailure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: AppErrorState(
          message: trainerFailureCopy(failure),
          onRetry: () =>
              context.read<TrainerChatBloc>().add(const TrainerChatStarted()),
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.state});

  final TrainerChatLoaded state;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView>
    with VoiceRecordingMixin<_ChatView> {
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
  void didUpdateWidget(_ChatView old) {
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

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
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
                  itemCount: s.messages.length + (s.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return LiveTypingProgress(
                        label: s.liveProgress,
                        keyId: 'trainer',
                      );
                    }
                    final idx =
                        s.messages.length - 1 - (i - (s.sending ? 1 : 0));
                    return TrainerMessageTile(message: s.messages[idx]);
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
        if (s.sending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            child: Align(
              alignment: Alignment.centerRight,
              child: AppButton.text(
                key: const Key('trainer.turn_cancel'),
                label: 'Detener',
                icon: Icons.stop_rounded,
                onPressed: () => context.read<TrainerChatBloc>().add(
                  const TrainerChatTurnCancelRequested(),
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
                    key: const Key('trainer.modality_warning'),
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
              key: const Key('trainer.pending_attachments'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
              itemCount: s.pendingAttachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppTokens.sp2),
              itemBuilder: (context, i) {
                final att = s.pendingAttachments[i];
                final thumb = s.pendingThumbnails[att.ref];
                return InputChip(
                  key: Key('trainer.pending_att.${att.ref}'),
                  avatar: thumb != null
                      // Miniatura real desde los bytes locales del pendiente.
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusSm,
                          ),
                          child: Image.memory(
                            thumb,
                            key: Key('trainer.pending_thumb.${att.ref}'),
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                            // Bytes que no decodifican (archivo corrupto) caen
                            // al ícono en vez de tumbar la fila.
                            errorBuilder: (_, _, _) =>
                                Icon(attachmentIcon(att.mime), size: 16),
                          ),
                        )
                      : Icon(attachmentIcon(att.mime), size: 16),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  label: Text(att.name, overflow: TextOverflow.ellipsis),
                  onDeleted: () => context.read<TrainerChatBloc>().add(
                    TrainerChatAttachmentRemoved(att.ref),
                  ),
                );
              },
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
