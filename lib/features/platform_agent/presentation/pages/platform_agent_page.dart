import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/audio_recorder.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/live_typing_progress.dart';
import '../../../../core/design/widgets/voice_recording_bar.dart';
import '../../domain/entities/pa_conversation.dart';
import '../../domain/failures/pa_failure.dart';
import '../bloc/platform_agent_chat_bloc.dart';
import '../widgets/pa_failure_copy.dart';
import '../widgets/pa_message_tile.dart';

/// Pestaña del asistente de plataforma: chat conversacional con el operador.
/// Vive como tab del shell (no como overlay), así hereda del Scaffold el
/// resize por teclado y el back estándar. Lee `PlatformAgentChatBloc` del
/// context (provisto arriba del shell) y dispara la carga la primera vez que
/// la tab se abre (init perezoso: solo si el estado sigue en Loading).
class PlatformAgentPage extends StatefulWidget {
  const PlatformAgentPage({super.key});

  @override
  State<PlatformAgentPage> createState() => _PlatformAgentPageState();
}

class _PlatformAgentPageState extends State<PlatformAgentPage> {
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    // Carga perezosa: la tab solo se construye cuando se abre. Si el bloc
    // sigue en su estado inicial, arrancamos; si ya cargó (re-entrada a la
    // tab), conservamos el hilo vivo.
    final bloc = context.read<PlatformAgentChatBloc>();
    if (bloc.state is PaChatLoading) {
      bloc.add(const PaChatStarted());
    }
  }

  void _send(String text) {
    final bloc = context.read<PlatformAgentChatBloc>();
    final s = bloc.state;
    // No despachar con un lote de adjuntos a medio subir: cerraría el turno con
    // un subconjunto y perdería en silencio los que aún suben.
    if (s is PaChatLoaded && (s.sending || s.attaching)) return;
    bloc.add(PaChatMessageSent(text));
  }

  void _select(String id) {
    context.read<PlatformAgentChatBloc>().add(PaChatConversationSelected(id));
    setState(() => _showHistory = false);
  }

  void _rename(String id, String title) {
    context.read<PlatformAgentChatBloc>().add(
      PaChatConversationRenamed(id, title),
    );
  }

  void _delete(String id) {
    context.read<PlatformAgentChatBloc>().add(PaChatConversationDeleted(id));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pa.page'),
      color: AppTokens.bgBase,
      child: Column(
        children: <Widget>[
          _Header(
            showHistory: _showHistory,
            onToggleHistory: () => setState(() => _showHistory = !_showHistory),
            onNew: () => context.read<PlatformAgentChatBloc>().add(
              const PaChatNewConversationRequested(),
            ),
          ),
          Expanded(
            child: BlocBuilder<PlatformAgentChatBloc, PaChatState>(
              builder: (context, state) => switch (state) {
                PaChatLoading() => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.primary,
                    ),
                  ),
                ),
                PaChatFailed(:final failure) => _FailedView(failure: failure),
                PaChatLoaded() =>
                  _showHistory
                      ? _HistoryList(
                          conversations: state.conversations,
                          activeId: state.activeConversation.id,
                          onSelect: _select,
                          onRename: _rename,
                          onDelete: _delete,
                        )
                      : _ChatView(state: state, onSend: _send),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Header full-bleed de la pestaña: reserva el inset del status bar (como las
/// demás tabs del shell, que van sin AppBar). Marca + acciones de modelo,
/// historial y nuevo hilo.
///
/// Deliberadamente NO es la tarjeta-header gradiente de las secciones: esta
/// tab es un chat (hilo + composer fijos, sin scroll que se lleve el header),
/// así que el chrome compacto tipo app bar — como el del hilo de mensajes —
/// preserva la altura del hilo con el teclado abierto; además sus acciones
/// comunican estado por color (modelo elegido, historial abierto), lenguaje
/// que no lee sobre el gradiente de marca.
class _Header extends StatelessWidget {
  const _Header({
    required this.showHistory,
    required this.onToggleHistory,
    required this.onNew,
  });

  final bool showHistory;
  final VoidCallback onToggleHistory;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp3,
        topInset + AppTokens.sp2,
        AppTokens.sp1,
        AppTokens.sp2,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(bottom: BorderSide(color: AppTokens.divider)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 20, color: AppTokens.primary),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Text(
              'Asistente',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTokens.text1),
            ),
          ),
          const _ModelMenu(),
          IconButton(
            key: const Key('pa.history'),
            tooltip: 'Conversaciones',
            icon: Icon(
              Icons.history,
              color: showHistory ? AppTokens.primary : AppTokens.text2,
            ),
            onPressed: onToggleHistory,
          ),
          IconButton(
            key: const Key('pa.new_conversation'),
            tooltip: 'Nueva conversación',
            icon: const Icon(
              Icons.add_comment_outlined,
              color: AppTokens.text2,
            ),
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

/// Menú de modelo del asistente. Solo aparece cuando el server expone la
/// allowlist (estado Loaded con modelos); elegir "Por defecto" regresa al
/// modelo de la plataforma (el turno viaja sin `model`). La elección vive en
/// el estado del bloc — por sesión de pantalla, no se persiste.
class _ModelMenu extends StatelessWidget {
  const _ModelMenu();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformAgentChatBloc, PaChatState>(
      builder: (context, state) {
        if (state is! PaChatLoaded || state.models.isEmpty) {
          return const SizedBox.shrink();
        }
        final selected = state.selectedModelId;
        return PopupMenuButton<String>(
          key: const Key('pa.model.button'),
          tooltip: 'Modelo del asistente',
          icon: Icon(
            Icons.psychology_outlined,
            color: selected.isEmpty ? AppTokens.text2 : AppTokens.primary,
          ),
          onSelected: (id) => context.read<PlatformAgentChatBloc>().add(
            PaChatModelSelected(id),
          ),
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              key: const Key('pa.model.option.default'),
              value: '',
              checked: selected.isEmpty,
              child: const Text('Por defecto'),
            ),
            for (final m in state.models)
              CheckedPopupMenuItem<String>(
                key: Key('pa.model.option.${m.id}'),
                value: m.id,
                checked: selected == m.id,
                child: Text(
                  m.id == state.defaultModelId
                      ? '${m.label} (por defecto)'
                      : m.label,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final PaFailure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              platformAgentFailureCopy(failure),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.sp3),
            KeyedSubtree(
              key: const Key('pa.retry'),
              child: AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<PlatformAgentChatBloc>().add(
                  const PaChatStarted(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final List<PaConversation> conversations;
  final String activeId;
  final ValueChanged<String> onSelect;
  final void Function(String id, String title) onRename;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('pa.history.list'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp2),
      itemCount: conversations.length,
      itemBuilder: (context, i) {
        final c = conversations[i];
        final active = c.id == activeId;
        return ListTile(
          key: Key('pa.history.item.${c.id}'),
          leading: Icon(
            Icons.chat_bubble_outline,
            color: active ? AppTokens.primary : AppTokens.text2,
          ),
          title: Text(
            c.title.isNotEmpty ? c.title : 'Conversación',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: active ? AppTokens.primary : AppTokens.text1,
            ),
          ),
          trailing: PopupMenuButton<String>(
            key: Key('pa.history.menu.${c.id}'),
            icon: const Icon(Icons.more_vert, color: AppTokens.text2),
            onSelected: (action) {
              if (action == 'rename') {
                _promptRename(context, c);
              } else if (action == 'delete') {
                _confirmDelete(context, c);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem<String>(value: 'delete', child: Text('Eliminar')),
            ],
          ),
          onTap: () => onSelect(c.id),
        );
      },
    );
  }

  Future<void> _promptRename(BuildContext context, PaConversation c) async {
    final ctrl = TextEditingController(text: c.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Renombrar conversación'),
        content: TextField(
          key: const Key('pa.history.rename.field'),
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('pa.history.rename.confirm'),
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newTitle != null && newTitle.isNotEmpty && newTitle != c.title) {
      onRename(c.id, newTitle);
    }
  }

  Future<void> _confirmDelete(BuildContext context, PaConversation c) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar conversación',
      message: 'Se borrará el hilo y sus mensajes. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmKey: const Key('pa.history.delete.confirm'),
    );
    if (ok) onDelete(c.id);
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({required this.state, required this.onSend});

  final PaChatLoaded state;
  final ValueChanged<String> onSend;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  /// Controller compartido: las acciones rápidas PREFIJAN el texto del composer
  /// (el operador lo edita antes de enviar) en vez de auto-enviar. También es el
  /// origen del borrador, que el bloc persiste por hilo.
  final TextEditingController _composer = TextEditingController();

  /// Bloc capturado al montar: lo usa el ciclo de la nota de voz (incluida la
  /// limpieza en dispose, cuando el context ya no es fiable).
  late final PlatformAgentChatBloc _bloc;

  /// Grabador compartido (Noop/ausente fuera de Android): NO se dispone aquí.
  /// null ⇒ la superficie no ofrece el micrófono.
  AudioRecorder? _recorder;

  /// La plataforma puede grabar (Opus soportado). Falso ⇒ sin micrófono.
  bool _canRecord = false;

  /// Grabando localmente: guía la limpieza en dispose (aborta el clip huérfano
  /// si el composer se destruye a media grabación, p. ej. al cambiar de tab).
  bool _recording = false;

  /// Grabación pausada (manos libres): congela tiempo+waveform sin descartar.
  bool _paused = false;

  /// Subiendo el clip tras detener: deshabilita enviar/pausar en la barra.
  bool _sendingVoice = false;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<PlatformAgentChatBloc>();
    // Al (re)montar —incl. al volver a la pestaña del shell, que destruyó el
    // composer— resembrar desde el borrador VIVO del bloc, no desde state.draft
    // (que está rancio: DraftChanged no emite). Así el texto sin enviar persiste.
    _composer.text = _bloc.activeDraft;
    _composer.addListener(_onComposerChanged);
    _recorder = _readRecorder(context);
    _recorder?.isSupported().then((ok) {
      if (mounted) setState(() => _canRecord = ok);
    });
  }

  /// Lee el grabador del scope de forma tolerante: superficies sin él cableado
  /// (tests, plataforma sin micrófono) simplemente no ofrecen la nota de voz.
  AudioRecorder? _readRecorder(BuildContext context) {
    try {
      return context.read<AudioRecorder>();
    } on Object {
      return null;
    }
  }

  @override
  void didUpdateWidget(_ChatView old) {
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
    // Grabación viva al destruirse el composer (p. ej. cambio de tab): aborta
    // el clip huérfano y revierte el estado del bloc para no volver a una barra
    // de grabación sin grabador detrás.
    if (_recording) {
      unawaited(_recorder?.cancel());
      if (!_bloc.isClosed) _bloc.add(const PaChatVoiceCancelled());
    }
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    super.dispose();
  }

  // ── Nota de voz ──────────────────────────────────────────────────────────

  /// Tap del micrófono: pide permiso y arranca la grabación en modo bloqueado
  /// (sin gesto de mantener). Sin permiso o ante un fallo del arranque, avisa y
  /// no entra a grabar.
  Future<void> _startVoice() async {
    final rec = _recorder;
    if (rec == null || _recording) return;
    final messenger = ScaffoldMessenger.of(context);
    final granted = await rec.hasPermission();
    if (!mounted) return;
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Permite el micrófono para grabar notas de voz'),
        ),
      );
      return;
    }
    try {
      await rec.start();
    } on Object {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la grabación')),
        );
      }
      return;
    }
    if (!mounted) {
      unawaited(rec.cancel());
      return;
    }
    setState(() => _recording = true);
    _bloc.add(const PaChatVoiceStarted());
  }

  /// Descarta la grabación en curso sin enviarla.
  Future<void> _cancelVoice() async {
    await _recorder?.cancel();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
      _sendingVoice = false;
    });
    _bloc.add(const PaChatVoiceCancelled());
  }

  /// Detiene la grabación y despacha el clip: el bloc corre el turno vía audio.
  /// Un clip vacío se descarta con aviso.
  Future<void> _sendVoice() async {
    final rec = _recorder;
    if (rec == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingVoice = true);
    RecordedVoice? voice;
    try {
      voice = await rec.stop();
    } on Object {
      voice = null;
    }
    if (!mounted) return;
    if (voice == null || voice.bytes.isEmpty) {
      setState(() {
        _recording = false;
        _paused = false;
        _sendingVoice = false;
      });
      _bloc.add(const PaChatVoiceCancelled());
      messenger.showSnackBar(
        const SnackBar(content: Text('No se grabó audio')),
      );
      return;
    }
    _bloc.add(PaChatVoiceSent(voice.bytes));
    if (mounted) {
      setState(() {
        _recording = false;
        _paused = false;
        _sendingVoice = false;
      });
    }
  }

  /// Pausa/reanuda la grabación (manos libres). No aplica durante la subida.
  Future<void> _togglePauseVoice() async {
    final rec = _recorder;
    if (rec == null || _sendingVoice) return;
    if (_paused) {
      await rec.resume();
      if (mounted) setState(() => _paused = false);
    } else {
      await rec.pause();
      if (mounted) setState(() => _paused = true);
    }
  }

  void _prefill(String text) {
    _composer.text = text;
    _composer.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final onSend = widget.onSend;
    return Column(
      children: <Widget>[
        Expanded(
          child: (s.messages.isEmpty && !s.sending)
              ? _EmptyHint(onQuickAction: _prefill)
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
                        onTap: () => context.read<PlatformAgentChatBloc>().add(
                          const PaChatLoadMore(),
                        ),
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
              separatorBuilder: (_, _) => const SizedBox(width: AppTokens.sp2),
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
        if (s.recordingVoice && _recorder != null)
          VoiceRecordingBar(
            elapsed: _recorder!.elapsed,
            amplitude: _recorder!.amplitude,
            onCancel: _cancelVoice,
            onSend: _sendVoice,
            onPauseResume: _togglePauseVoice,
            paused: _paused,
            sending: _sendingVoice,
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
            emptyTrailing: (_canRecord && s.pendingAttachments.isEmpty)
                ? IconButton(
                    key: const Key('pa.voice.mic'),
                    tooltip: 'Grabar nota de voz',
                    icon: const Icon(
                      Icons.mic_none_outlined,
                      color: AppTokens.text2,
                    ),
                    onPressed: _startVoice,
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
    );
  }
}

/// Una acción rápida del estado vacío: etiqueta visible + texto con el que
/// prefija el composer (puede diferir, p.ej. dejar el bot/flujo a completar).
class _QuickAction {
  const _QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.prefill,
  });

  final String id;
  final String label;
  final IconData icon;
  final String prefill;
}

const List<_QuickAction> _quickActions = <_QuickAction>[
  _QuickAction(
    id: 'bots',
    label: '¿Cuántos bots tengo?',
    icon: Icons.smart_toy_outlined,
    prefill: '¿Cuántos bots tengo y cómo se llaman?',
  ),
  _QuickAction(
    id: 'pause',
    label: 'Pausar un bot',
    icon: Icons.pause_circle_outline,
    prefill: 'Pausa el bot ',
  ),
  _QuickAction(
    id: 'audit',
    label: 'Auditar un flujo',
    icon: Icons.fact_check_outlined,
    prefill: 'Audita el flujo ',
  ),
  _QuickAction(
    id: 'clone',
    label: 'Duplicar un flujo',
    icon: Icons.copy_all_outlined,
    prefill: 'Duplica el flujo ',
  ),
];

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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onQuickAction});

  /// Prefija el composer con el arranque de una acción rápida.
  final ValueChanged<String> onQuickAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('pa.empty_hint'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.auto_awesome, size: 48, color: AppTokens.primary),
            const SizedBox(height: AppTokens.sp3),
            Text(
              'Tu asistente de plataforma',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: AppTokens.text1),
            ),
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Pídele que liste tus bots, ajuste una plantilla, cree o borre '
              'flujos, o apague la IA de un bot. Te pedirá confirmación cuando '
              'un cambio afecte a varios bots.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppTokens.sp2,
              runSpacing: AppTokens.sp2,
              children: <Widget>[
                for (final a in _quickActions)
                  ActionChip(
                    key: Key('pa.quick_action.${a.id}'),
                    avatar: Icon(a.icon, size: 16, color: AppTokens.primary),
                    label: Text(a.label),
                    onPressed: () => onQuickAction(a.prefill),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
