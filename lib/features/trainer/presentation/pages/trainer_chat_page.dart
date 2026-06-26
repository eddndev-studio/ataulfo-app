import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/reasoning_disclosure.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
import '../../domain/entities/trainer_conversation.dart';
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

  void _showThreads(BuildContext context) {
    final bloc = context.read<TrainerChatBloc>();
    final state = bloc.state;
    if (state is! TrainerChatLoaded) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => _ThreadList(
        conversations: state.conversations,
        activeId: state.conversation.id,
        onSelect: (id) {
          bloc.add(TrainerChatConversationSelected(id));
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
  }
}

/// Selector de hilos: lista de conversaciones del entrenamiento (la activa
/// marcada). Tocar una la activa y cierra el cajón.
class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.conversations,
    required this.activeId,
    required this.onSelect,
  });

  final List<TrainerConversation> conversations;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        key: const Key('trainer.threads.list'),
        shrinkWrap: true,
        children: <Widget>[
          for (final c in conversations)
            ListTile(
              key: Key('trainer.threads.item.${c.id}'),
              leading: Icon(
                c.id == activeId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: c.id == activeId ? AppTokens.primary : AppTokens.text2,
              ),
              title: Text(c.title),
              selected: c.id == activeId,
              onTap: () => onSelect(c.id),
            ),
        ],
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
          // Hilo vacío en reposo: el área del chat quedaría en blanco, así que
          // la ocupa un tip que orienta al operador sobre qué hacer (convive
          // con los chips de arranque de abajo).
          child: (s.messages.isEmpty && !s.sending)
              ? const _EmptyHint()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppTokens.sp3),
                  itemCount: s.messages.length + (s.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return _LiveProgress(label: s.liveProgress);
                    }
                    final idx =
                        s.messages.length - 1 - (i - (s.sending ? 1 : 0));
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
                return InputChip(
                  key: Key('trainer.pending_att.${att.ref}'),
                  avatar: Icon(attachmentIcon(att.mime), size: 16),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  label: Text(att.name, overflow: TextOverflow.ellipsis),
                  onDeleted: () => context.read<TrainerChatBloc>().add(
                    TrainerChatAttachmentRemoved(att.ref),
                  ),
                );
              },
            ),
          ),
        AppChatComposer(
          fieldKey: const Key('trainer.composer.field'),
          sendKey: const Key('trainer.composer.send'),
          hint: 'Cuéntale de tu negocio…',
          enabled: !s.sending,
          onSend: _send,
          leading: <Widget>[
            IconButton(
              key: const Key('trainer.attach'),
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

/// Indicador en vivo del turno: la burbuja de "escribiendo" + la etiqueta de
/// progreso del SSE ("Pensando…/Usando {tool}…"). Sin etiqueta (SSE no conectó
/// aún) muestra solo el typing.
class _LiveProgress extends StatelessWidget {
  const _LiveProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const TypingBubble(key: Key('trainer.typing')),
        if (label.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppTokens.sp2),
          Flexible(
            child: Text(
              label,
              key: const Key('trainer.live_progress'),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
          ),
        ],
      ],
    );
  }
}

/// Estado vacío del hilo: un tip de fondo que orienta al operador sobre qué
/// hacer con el entrenador. Ocupa el área del chat —que de otro modo quedaría
/// en blanco— y complementa los chips de arranque, que viven abajo.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Scrolleable: si el teclado encoge el área del hilo, el tip se desplaza
    // en vez de desbordar (y se centra mientras haya espacio de sobra).
    return Center(
      key: const Key('trainer.empty_hint'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.school_outlined,
              size: 48,
              color: AppTokens.primary,
            ),
            const SizedBox(height: AppTokens.sp3),
            Text(
              'Entrena a tu bot',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: AppTokens.text1),
            ),
            const SizedBox(height: AppTokens.sp2),
            Text(
              'Cuéntale al entrenador sobre tu negocio —menú, horarios, tono— y '
              'él irá afinando el prompt y el workspace por ti. Empieza con una '
              'sugerencia de abajo o escribe tu primer mensaje.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
      ),
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
      final inspect = _InspectFlowData.fromMessage(message);
      if (inspect != null) {
        return _InspectFlowCard(messageId: message.id, data: inspect);
      }
      final err = _ToolErrorData.fromMessage(message);
      if (err != null) {
        return _ToolErrorCard(messageId: message.id, data: err);
      }
      final card = _ChangeCardData.fromMessage(message);
      if (card == null) return const SizedBox.shrink();
      return _ChangeCard(messageId: message.id, data: card);
    }
    if (message.isAssistant &&
        message.content.isEmpty &&
        message.thinking.isEmpty) {
      // Turno puro tool_calls: la acción se cuenta con la tarjeta del tool
      // result; una burbuja vacía solo mete ruido.
      return const SizedBox.shrink();
    }
    final bubble = ChatBubble(
      mine: message.isUser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (message.attachments.isNotEmpty) ...<Widget>[
            for (final att in message.attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      attachmentIcon(att.mime),
                      size: 16,
                      color: AppTokens.text2,
                    ),
                    const SizedBox(width: AppTokens.sp1),
                    Flexible(
                      child: Text(
                        att.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (message.content.isNotEmpty)
            Text(
              message.content,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
            ),
        ],
      ),
    );
    // El razonamiento del assistant (si viaja) va colapsado SOBRE la burbuja.
    if (message.isAssistant && message.thinking.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ReasoningDisclosure(reasoning: message.thinking, keyId: message.id),
          if (message.content.isNotEmpty || message.attachments.isNotEmpty)
            bubble,
        ],
      );
    }
    return bubble;
  }
}

/// Ícono por MIME del adjunto (imagen/PDF; resto genérico).
IconData attachmentIcon(String mime) {
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.description_outlined;
  return Icons.attach_file;
}

/// Diff embebido en el envelope de una tool de escritura (puede faltar:
/// historial previo al server que lo computa — la tarjeta degrada).
class _ChangeDiff {
  const _ChangeDiff({required this.oldStr, required this.newStr});

  final String oldStr;
  final String newStr;
}

/// Datos de una tarjeta de cambio: proyección de un tool result de
/// escritura. Las lecturas (overview/read_*/list_*/done) no rinden tarjeta.
/// `name`/`diff` salen del envelope ANIDADO (content es un string JSON) y
/// alimentan la vista expandida; sin detalle, la tarjeta es plana.
/// Un fallo de tool (error_kind) que antes se descartaba: ahora el operador lo
/// ve. toolName + el envelope error_kind, traducido a copy legible.
class _ToolErrorData {
  const _ToolErrorData({required this.toolName, required this.kind});

  final String toolName;
  final String kind;

  static _ToolErrorData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final content = decoded['content'];
    if (content is! String) return null;
    Object? inner;
    try {
      inner = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (inner is! Map<String, dynamic>) return null;
    final kind = inner['error_kind'];
    if (kind is! String || kind.isEmpty) return null;
    return _ToolErrorData(
      toolName: decoded['toolName']?.toString() ?? '',
      kind: kind,
    );
  }
}

/// Traduce un error_kind del entrenador a copy en español para el operador.
String trainerToolErrorCopy(String kind) {
  switch (kind) {
    case 'anchor_not_found':
      return 'No encontré el ancla en el texto actual; vuelve a leerlo y reintenta.';
    case 'anchor_not_unique':
      return 'El ancla aparece varias veces; agrega contexto para que sea única.';
    case 'empty_anchor':
      return 'El ancla vacía solo aplica sobre contenido vacío (bootstrap).';
    case 'no_change':
      return 'El texto nuevo es igual al anterior: no hubo cambio.';
    case 'not_found':
      return 'No se encontró el recurso.';
    case 'already_exists':
      return 'Ya existe un recurso con ese nombre.';
    case 'invalid_input':
      return 'Dato inválido por las reglas del negocio.';
    case 'invalid_args':
      return 'Argumentos inválidos para la herramienta.';
    case 'version_conflict':
      return 'Conflicto de versión: algo cambió mientras editabas, reintenta.';
    case 'variable_in_use':
      return 'La variable está en uso por algún bot; limpia esos valores primero.';
    default:
      return 'La herramienta falló ($kind).';
  }
}

/// Tarjeta de error de un tool: registro centrado de un fallo (no una burbuja).
class _ToolErrorCard extends StatelessWidget {
  const _ToolErrorCard({required this.messageId, required this.data});

  final String messageId;
  final _ToolErrorData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.center,
      child: Container(
        key: Key('trainer.error_card.$messageId'),
        margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp3,
          vertical: AppTokens.sp2,
        ),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(color: AppTokens.danger),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppTokens.danger,
            ),
            const SizedBox(width: AppTokens.sp2),
            Flexible(
              child: Text(
                data.toolName.isNotEmpty
                    ? '${data.toolName}: ${trainerToolErrorCopy(data.kind)}'
                    : trainerToolErrorCopy(data.kind),
                style: theme.textTheme.bodySmall?.copyWith(color: AppTokens.text1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeCardData {
  const _ChangeCardData({
    required this.icon,
    required this.title,
    this.name,
    this.diff,
  });

  final IconData icon;
  final String title;
  final String? name;
  final _ChangeDiff? diff;

  bool get expandable => name != null || diff != null;

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

    // El envelope de la tool viaja como STRING JSON dentro de content.
    String? name;
    _ChangeDiff? diff;
    if (content is String) {
      try {
        final env = jsonDecode(content);
        if (env is Map<String, dynamic>) {
          if (env['name'] is String) name = env['name'] as String;
          final d = env['diff'];
          if (d is Map<String, dynamic> &&
              (d['old'] is String || d['new'] is String)) {
            diff = _ChangeDiff(
              oldStr: d['old'] is String ? d['old'] as String : '',
              newStr: d['new'] is String ? d['new'] as String : '',
            );
          }
        }
      } on FormatException {
        // Content no-JSON: la tarjeta queda plana.
      }
    }
    return switch (tool) {
      'edit_prompt' => _ChangeCardData(
        icon: Icons.edit_note,
        title: 'Prompt actualizado',
        name: name,
        diff: diff,
      ),
      'write_doc' => _ChangeCardData(
        icon: Icons.note_add_outlined,
        title: 'Documento creado',
        name: name,
        diff: diff,
      ),
      'edit_doc' => _ChangeCardData(
        icon: Icons.edit_document,
        title: 'Documento actualizado',
        name: name,
        diff: diff,
      ),
      'delete_doc' => _ChangeCardData(
        icon: Icons.delete_outline,
        title: 'Documento borrado',
        name: name,
      ),
      'save_file' => _ChangeCardData(
        icon: Icons.attach_file,
        title: 'Archivo guardado',
        name: name,
      ),
      'update_file_meta' => _ChangeCardData(
        icon: Icons.edit_attributes_outlined,
        title: 'Archivo actualizado',
        name: name,
      ),
      'delete_file' => _ChangeCardData(
        icon: Icons.delete_outline,
        title: 'Archivo borrado',
        name: name,
      ),
      _ => null,
    };
  }
}

/// Un paso del flujo, proyectado para la tarjeta de inspección.
class _InspectStep {
  const _InspectStep({
    required this.type,
    required this.content,
    required this.mediaRef,
  });

  final String type;
  final String content;
  final String mediaRef;

  /// Resumen legible: el contenido (texto) o, si es multimedia, su ref.
  String get summary => content.isNotEmpty ? content : mediaRef;
}

/// Resultado de inspect_flow proyectado a la tarjeta: nombre del flujo + sus
/// pasos en orden y los disparadores que lo activan. El envelope del wire del
/// entrenador es camelCase ({toolName, content}); content es un STRING JSON
/// doble-codificado con la estructura del flujo (claves snake_case).
class _InspectFlowData {
  const _InspectFlowData({
    required this.name,
    required this.isActive,
    required this.steps,
    required this.triggers,
  });

  final String name;
  final bool isActive;
  final List<_InspectStep> steps;
  final List<String> triggers;

  static _InspectFlowData? fromMessage(TrainerMessage m) {
    final raw = m.toolResultsRaw;
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['toolName'] != 'inspect_flow') return null;
    final content = decoded['content'];
    if (content is! String) return null;
    Object? inner;
    try {
      inner = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (inner is! Map<String, dynamic>) return null;
    if (inner.containsKey('error_kind')) return null; // un error no es inspección

    final steps = <_InspectStep>[];
    final rawSteps = inner['steps'];
    if (rawSteps is List) {
      for (final s in rawSteps) {
        if (s is Map<String, dynamic>) {
          steps.add(
            _InspectStep(
              type: s['type']?.toString() ?? '',
              content: s['content']?.toString() ?? '',
              mediaRef: s['media_ref']?.toString() ?? '',
            ),
          );
        }
      }
    }
    final triggers = <String>[];
    final rawTriggers = inner['triggers'];
    if (rawTriggers is List) {
      for (final tr in rawTriggers) {
        if (tr is Map<String, dynamic>) {
          triggers.add(_triggerLabel(tr));
        }
      }
    }
    return _InspectFlowData(
      name: inner['name']?.toString() ?? 'Flujo',
      isActive: inner['is_active'] == true,
      steps: steps,
      triggers: triggers,
    );
  }

  static String _triggerLabel(Map<String, dynamic> tr) {
    final type = tr['trigger_type']?.toString() ?? '';
    if (type == 'TEXT') {
      return "TEXT '${tr['keyword']?.toString() ?? ''}'";
    }
    if (type == 'LABEL') {
      return 'LABEL ${tr['label_action']?.toString() ?? ''}';
    }
    return type;
  }
}

/// Ícono por tipo de paso (para la tarjeta de inspección).
IconData _stepTypeIcon(String type) => switch (type) {
  'TEXT' => Icons.short_text,
  'IMAGE' => Icons.image_outlined,
  'VIDEO' => Icons.videocam_outlined,
  'DOCUMENT' => Icons.description_outlined,
  'AUDIO' || 'PTT' => Icons.audiotrack_outlined,
  'STICKER' => Icons.emoji_emotions_outlined,
  'LABEL' => Icons.label_outline,
  'CONDITIONAL_TIME' => Icons.schedule_outlined,
  'END' => Icons.stop_circle_outlined,
  _ => Icons.circle_outlined,
};

/// Tarjeta de inspección de un flujo (resultado de inspect_flow): el entrenador
/// ve la estructura sin abrir el editor. Colapsada muestra el nombre + conteos;
/// al tocarla expande los pasos (con su ícono de tipo) y los disparadores.
class _InspectFlowCard extends StatefulWidget {
  const _InspectFlowCard({required this.messageId, required this.data});

  final String messageId;
  final _InspectFlowData data;

  @override
  State<_InspectFlowCard> createState() => _InspectFlowCardState();
}

class _InspectFlowCardState extends State<_InspectFlowCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = Theme.of(context);
    final header = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.account_tree_outlined, size: 16, color: AppTokens.primary),
        const SizedBox(width: AppTokens.sp2),
        Flexible(
          child: Text(
            'Flujo: ${data.name}',
            style: theme.textTheme.labelMedium?.copyWith(color: AppTokens.text1),
          ),
        ),
        const SizedBox(width: AppTokens.sp1),
        Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          key: Key('trainer.inspect_card.${widget.messageId}.expand'),
          size: 16,
          color: AppTokens.text2,
        ),
      ],
    );
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          key: Key('trainer.inspect_card.${widget.messageId}'),
          margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp3,
            vertical: AppTokens.sp2,
          ),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(
              _expanded ? AppTokens.radiusCard : AppTokens.radiusPill,
            ),
            border: Border.all(color: AppTokens.divider),
          ),
          child: _expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: AppTokens.sp2),
                    _InspectFlowDetail(data: data),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.sp1),
                      child: Text(
                        '${data.steps.length} pasos · ${data.triggers.length} disparadores',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InspectFlowDetail extends StatelessWidget {
  const _InspectFlowDetail({required this.data});

  final _InspectFlowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: AppTokens.text1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < data.steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  _stepTypeIcon(data.steps[i].type),
                  size: 14,
                  color: AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp2),
                Expanded(
                  child: Text('${i + 1}. ${data.steps[i].summary}', style: small),
                ),
              ],
            ),
          ),
        if (data.triggers.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Disparadores',
            style: theme.textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          for (final t in data.triggers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.sp1 / 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.bolt_outlined, size: 14, color: AppTokens.text2),
                  const SizedBox(width: AppTokens.sp2),
                  Flexible(child: Text(t, style: small)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Tarjeta de cambio: registro de que el entrenador escribió en el workspace.
/// Centrada como los chips de acción del preview — es un evento del hilo, no
/// una burbuja de nadie. Con detalle (nombre/diff) se expande al tocarla; el
/// estado vive en el widget (efímero, como el resto del transcript).
class _ChangeCard extends StatefulWidget {
  const _ChangeCard({required this.messageId, required this.data});

  final String messageId;
  final _ChangeCardData data;

  @override
  State<_ChangeCard> createState() => _ChangeCardState();
}

class _ChangeCardState extends State<_ChangeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final header = Row(
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
        if (data.expandable) ...<Widget>[
          const SizedBox(width: AppTokens.sp1),
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            key: Key('trainer.change_card.${widget.messageId}.expand'),
            size: 16,
            color: AppTokens.text2,
          ),
        ],
      ],
    );
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: data.expandable
            ? () => setState(() => _expanded = !_expanded)
            : null,
        child: Container(
          key: Key('trainer.change_card.${widget.messageId}'),
          margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp3,
            vertical: AppTokens.sp2,
          ),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(
              _expanded ? AppTokens.radiusCard : AppTokens.radiusPill,
            ),
            border: Border.all(color: AppTokens.divider),
          ),
          child: _expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: AppTokens.sp2),
                    _ChangeDetail(data: data),
                  ],
                )
              : header,
        ),
      ),
    );
  }
}

/// Cuerpo expandido: nombre del recurso + bloques del diff (lo reemplazado
/// y lo nuevo). Monospace para que el operador lea el texto literal.
class _ChangeDetail extends StatelessWidget {
  const _ChangeDetail({required this.data});

  final _ChangeCardData data;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppTokens.text1,
      fontFamily: 'monospace',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (data.name != null)
          Text(
            data.name!,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
        if (data.diff != null) ...<Widget>[
          if (data.diff!.oldStr.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp2),
            _diffBlock(
              data.diff!.oldStr,
              AppTokens.danger,
              mono?.copyWith(decoration: TextDecoration.lineThrough),
            ),
          ],
          if (data.diff!.newStr.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppTokens.sp1),
            _diffBlock(data.diff!.newStr, AppTokens.success, mono),
          ],
        ],
      ],
    );
  }

  Widget _diffBlock(String text, Color accent, TextStyle? style) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.sp2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Text(text, style: style),
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
