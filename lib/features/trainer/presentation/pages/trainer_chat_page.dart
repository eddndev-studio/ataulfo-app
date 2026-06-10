import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/trainer_message.dart';
import '../../domain/failures/trainer_failure.dart';
import '../bloc/trainer_chat_bloc.dart';

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
            key: const Key('trainer.new_conversation'),
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => context.read<TrainerChatBloc>().add(
              const TrainerChatNewConversationRequested(),
            ),
          ),
        ],
      ),
      body: BlocBuilder<TrainerChatBloc, TrainerChatState>(
        builder: (context, state) => switch (state) {
          TrainerChatLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          TrainerChatFailed(:final failure) => _FailedView(failure: failure),
          TrainerChatLoaded() => _ChatView(state: state),
        },
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final TrainerFailure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(trainerFailureCopy(failure), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                context.read<TrainerChatBloc>().add(const TrainerChatStarted()),
            child: const Text('Reintentar'),
          ),
        ],
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
  TrainerNotFoundFailure() => 'Eso ya no existe.',
  TrainerForbiddenFailure() => 'Necesitas rol ADMIN para esto.',
  TrainerNetworkFailure() => 'Sin conexión con el servidor.',
  TrainerTimeoutFailure() => 'La operación tardó demasiado.',
  TrainerServerFailure() => 'Error del servidor. Intenta más tarde.',
  TrainerUnknownFailure() => 'Algo salió mal.',
};

const List<String> _starterChips = <String>[
  '¿Qué necesitas saber de mi negocio?',
  'Muéstrame el prompt actual',
  'Resume el workspace',
  'Define el tono de respuesta',
  'Mejora el prompt',
];

class _ChatView extends StatefulWidget {
  const _ChatView({required this.state});

  final TrainerChatLoaded state;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || widget.state.sending) return;
    context.read<TrainerChatBloc>().add(TrainerChatMessageSent(text));
    if (preset == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: s.messages.length + (s.sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (s.sending && i == 0) return const _TypingBubble();
              final idx = s.messages.length - 1 - (i - (s.sending ? 1 : 0));
              return _MessageTile(message: s.messages[idx]);
            },
          ),
        ),
        if (s.sendFailure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              trainerFailureCopy(s.sendFailure!),
              key: const Key('trainer.send_failure'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (s.messages.isEmpty && !s.sending)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _starterChips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                key: Key('trainer.chip.$i'),
                label: Text(_starterChips[i]),
                onPressed: () => _send(_starterChips[i]),
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('trainer.composer.field'),
                    controller: _controller,
                    enabled: !s.sending,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Cuéntale de tu negocio…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('trainer.composer.send'),
                  onPressed: s.sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('trainer.typing'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Entrenando…'),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final TrainerMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isTool) {
      final card = _ChangeCardData.fromMessage(message);
      if (card == null) return const SizedBox.shrink();
      return _ChangeCard(messageId: message.id, data: card);
    }
    if (message.isAssistant && message.content.isEmpty) {
      // Turno puro tool_calls: la acción se cuenta con la tarjeta del tool
      // result; una burbuja vacía solo mete ruido.
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final mine = message.isUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content),
      ),
    );
  }
}

/// Datos de una tarjeta de cambio: proyección de un tool result de
/// escritura. Las lecturas (overview/read_*/list_*/done) no rinden tarjeta.
class _ChangeCardData {
  const _ChangeCardData({required this.icon, required this.title});

  final IconData icon;
  final String title;

  static _ChangeCardData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final tool = decoded['toolName'];
    final content = decoded['content'];
    final failed = content is String && content.contains('"error_kind"');
    if (failed) return null; // los envelopes de error no son cambios
    return switch (tool) {
      'edit_prompt' => const _ChangeCardData(
        icon: Icons.edit_note,
        title: 'Prompt actualizado',
      ),
      'write_doc' => const _ChangeCardData(
        icon: Icons.note_add_outlined,
        title: 'Documento creado',
      ),
      'edit_doc' => const _ChangeCardData(
        icon: Icons.edit_document,
        title: 'Documento actualizado',
      ),
      'delete_doc' => const _ChangeCardData(
        icon: Icons.delete_outline,
        title: 'Documento borrado',
      ),
      _ => null,
    };
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.messageId, required this.data});

  final String messageId;
  final _ChangeCardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: Key('trainer.change_card.$messageId'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(data.icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(data.title, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
