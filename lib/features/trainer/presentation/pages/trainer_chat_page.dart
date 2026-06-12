import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
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
          const _ModelMenu(),
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
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
            ),
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
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(trainerFailureCopy(failure), textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<TrainerChatBloc>().add(
                const TrainerChatStarted(),
              ),
            ),
          ],
        ),
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
  void _send(String text) {
    if (widget.state.sending) return;
    context.read<TrainerChatBloc>().add(TrainerChatMessageSent(text));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(AppTokens.sp3),
            itemCount: s.messages.length + (s.sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (s.sending && i == 0) {
                return const TypingBubble(key: Key('trainer.typing'));
              }
              final idx = s.messages.length - 1 - (i - (s.sending ? 1 : 0));
              return _MessageTile(message: s.messages[idx]);
            },
          ),
        ),
        if (s.sendFailure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            child: Text(
              trainerFailureCopy(s.sendFailure!),
              key: const Key('trainer.send_failure'),
              style: const TextStyle(color: AppTokens.danger),
            ),
          ),
        if (s.messages.isEmpty && !s.sending)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
              itemCount: _starterChips.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppTokens.sp2),
              itemBuilder: (context, i) => _StarterChip(
                chipKey: Key('trainer.chip.$i'),
                label: _starterChips[i],
                onTap: () => _send(_starterChips[i]),
              ),
            ),
          ),
        AppChatComposer(
          fieldKey: const Key('trainer.composer.field'),
          sendKey: const Key('trainer.composer.send'),
          hint: 'Cuéntale de tu negocio…',
          enabled: !s.sending,
          onSend: _send,
        ),
      ],
    );
  }
}

/// Chip de arranque para un hilo vacío: cápsula con borde hairline (idioma de
/// los chips del kit) que manda el preset como mensaje.
class _StarterChip extends StatelessWidget {
  const _StarterChip({
    required this.chipKey,
    required this.label,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusPill);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: chipKey,
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp3,
              vertical: AppTokens.sp2,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppTokens.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppTokens.primary,
                ),
                const SizedBox(width: AppTokens.sp1),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
                ),
              ],
            ),
          ),
        ),
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
    return ChatBubble(
      mine: message.isUser,
      child: Text(
        message.content,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
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

/// Tarjeta de cambio: registro de que el entrenador escribió en el workspace.
/// Centrada como los chips de acción del preview — es un evento del hilo, no
/// una burbuja de nadie.
class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.messageId, required this.data});

  final String messageId;
  final _ChangeCardData data;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: Key('trainer.change_card.$messageId'),
        margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp3,
          vertical: AppTokens.sp2,
        ),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: AppTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(data.icon, size: 16, color: AppTokens.primary),
            const SizedBox(width: AppTokens.sp2),
            Flexible(
              child: Text(
                data.title,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppTokens.text1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menú de modelo del entrenador. Solo aparece cuando el server expone la
/// allowlist (estado Loaded con modelos); elegir "Por defecto" regresa al
/// modelo de la plataforma (el turno viaja sin `model`). La elección vive en
/// el estado del bloc — por sesión de pantalla, no se persiste.
class _ModelMenu extends StatelessWidget {
  const _ModelMenu();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainerChatBloc, TrainerChatState>(
      builder: (context, state) {
        if (state is! TrainerChatLoaded || state.models.isEmpty) {
          return const SizedBox.shrink();
        }
        final selected = state.selectedModelId;
        return PopupMenuButton<String>(
          key: const Key('trainer.model.button'),
          tooltip: 'Modelo del entrenador',
          icon: Icon(
            Icons.psychology_outlined,
            color: selected.isEmpty ? null : AppTokens.primary,
          ),
          onSelected: (id) =>
              context.read<TrainerChatBloc>().add(TrainerChatModelSelected(id)),
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              key: const Key('trainer.model.option.default'),
              value: '',
              checked: selected.isEmpty,
              child: const Text('Por defecto'),
            ),
            for (final m in state.models)
              CheckedPopupMenuItem<String>(
                key: Key('trainer.model.option.${m.id}'),
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
