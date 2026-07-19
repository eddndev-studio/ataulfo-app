// Nota de tamaño (>400 LOC): la página del emulador concentra transcript
// (burbujas user/bot/acción/media), bandeja de adjuntos y composer del
// sandbox — piezas acopladas por el mismo layout; partirlas dispersaría la
// presentación sin ganar claridad.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/tool_glyphs.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
import '../../domain/entities/preview_item.dart';
import '../bloc/preview_bloc.dart';
import 'trainer_chat_page.dart' show trainerFailureCopy;

/// Emulador del Asistente: corre el MISMO motor que producción contra una sesión
/// sandbox. Nada llega a WhatsApp; los efectos (etiquetas, notas, flujos)
/// aparecen como chips grabados. Consume tokens reales del proveedor. Las
/// LECTURAS del bot (kind tool) viven tras un toggle: por defecto el hilo
/// muestra solo la conversación + efectos; el operador que diagnostica
/// enciende las herramientas.
class PreviewPage extends StatefulWidget {
  const PreviewPage({required this.templateId, super.key});

  final String templateId;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  bool _showTools = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Probar Asistente'),
        actions: <Widget>[
          BlocBuilder<PreviewBloc, PreviewState>(
            builder: (context, state) {
              final hasTools =
                  state is PreviewLoaded &&
                  state.items.any((PreviewItem it) => it.isTool);
              if (!hasTools) return const SizedBox.shrink();
              return IconButton(
                key: const Key('preview.tools_toggle'),
                tooltip: _showTools
                    ? 'Ocultar herramientas'
                    : 'Mostrar herramientas',
                icon: Icon(
                  _showTools ? Icons.visibility : Icons.visibility_outlined,
                  color: _showTools ? AppTokens.primary : null,
                ),
                onPressed: () => setState(() => _showTools = !_showTools),
              );
            },
          ),
          IconButton(
            key: const Key('preview.reset'),
            tooltip: 'Reiniciar demo',
            icon: const Icon(Icons.restart_alt),
            onPressed: () =>
                context.read<PreviewBloc>().add(const PreviewResetRequested()),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _DemoBanner(),
          Expanded(
            child: BlocBuilder<PreviewBloc, PreviewState>(
              builder: (context, state) => switch (state) {
                PreviewLoading() => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.primary,
                    ),
                  ),
                ),
                PreviewLoaded() => _PreviewThread(
                  state: state,
                  showTools: _showTools,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso permanente del sandbox: nada sale a WhatsApp, los efectos son chips
/// y el turno consume tokens reales. Franja sobria en surface1, no un toast.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('preview.banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp4,
        vertical: AppTokens.sp2,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(bottom: BorderSide(color: AppTokens.divider)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.science_outlined, size: 16, color: AppTokens.text2),
          const SizedBox(width: AppTokens.sp2),
          Expanded(
            child: Text(
              'Demo: nada se envía a WhatsApp. Las acciones aparecen como chips. Consume tokens reales.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewThread extends StatefulWidget {
  const _PreviewThread({required this.state, this.showTools = false});

  final PreviewLoaded state;
  final bool showTools;

  @override
  State<_PreviewThread> createState() => _PreviewThreadState();
}

class _PreviewThreadState extends State<_PreviewThread> {
  void _send(String text) {
    if (widget.state.sending) return;
    context.read<PreviewBloc>().add(PreviewMessageSent(text));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    // Las lecturas (kind tool) se filtran ANTES de indexar: el reverse
    // ListView cuenta sobre la lista visible, no sobre el transcript crudo.
    final items = widget.showTools
        ? s.items
        : s.items.where((PreviewItem it) => !it.isTool).toList();
    return Column(
      children: <Widget>[
        Expanded(
          child: items.isEmpty && !s.sending
              ? const _EmptyView()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppTokens.sp3),
                  itemCount: items.length + (s.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return const TypingBubble(key: Key('preview.typing'));
                    }
                    final idx = items.length - 1 - (i - (s.sending ? 1 : 0));
                    return _ItemTile(item: items[idx]);
                  },
                ),
        ),
        if (s.failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            child: Text(
              trainerFailureCopy(s.failure!),
              key: const Key('preview.failure'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTokens.danger),
            ),
          ),
        if (s.accumulatingUntil != null) const _AccumulatingBanner(),
        if (s.pendingAttachments.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              key: const Key('preview.pending_attachments'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
              itemCount: s.pendingAttachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppTokens.sp2),
              itemBuilder: (context, i) {
                final att = s.pendingAttachments[i];
                final isImage = _looksLikeImage(att.name);
                return InputChip(
                  key: Key('preview.pending_att.${att.name}'),
                  // Miniatura real para imágenes (los bytes ya están en
                  // memoria); ícono por tipo para el resto — el mismo trato
                  // que la bandeja del entrenador/asistente.
                  avatar: isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusSm,
                          ),
                          child: Image.memory(
                            att.bytes,
                            key: Key('preview.pending_thumb.${att.name}'),
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                            // Bytes que no decodifican caen al ícono en vez
                            // de tumbar la fila.
                            errorBuilder: (_, _, _) =>
                                Icon(_pendingIcon(att.name), size: 16),
                          ),
                        )
                      : Icon(_pendingIcon(att.name), size: 16),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  label: Text(att.name, overflow: TextOverflow.ellipsis),
                  onDeleted: () => context.read<PreviewBloc>().add(
                    PreviewAttachmentRemoved(att.name),
                  ),
                );
              },
            ),
          ),
        AppChatComposer(
          fieldKey: const Key('preview.composer.field'),
          sendKey: const Key('preview.composer.send'),
          hint: 'Escribe como cliente…',
          enabled: !s.sending,
          onSend: _send,
          leading: <Widget>[
            IconButton(
              key: const Key('preview.attach'),
              tooltip: 'Adjuntar imagen o PDF',
              icon: const Icon(Icons.attach_file, color: AppTokens.text2),
              onPressed: s.sending
                  ? null
                  : () => context.read<PreviewBloc>().add(
                      const PreviewAttachRequested(),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// El adjunto pendiente parece imagen por su extensión (el sandbox no conoce
/// el MIME: el server lo sniffea al recibirlo).
bool _looksLikeImage(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  return ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp';
}

/// Ícono del adjunto pendiente por extensión (imagen/PDF; resto genérico) —
/// espejo del `attachmentIcon` por MIME de los chats reales.
IconData _pendingIcon(String name) {
  if (_looksLikeImage(name)) return Icons.image_outlined;
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  if (ext == 'pdf') return Icons.description_outlined;
  return Icons.attach_file;
}

/// Pill sobre el composer mientras la ventana de acumulación está viva: el
/// bot junta los mensajes y responderá todo al cerrarla. Sin typing — el
/// typing es "está respondiendo", esto es "está escuchando". El composer
/// queda habilitado: cada envío se suma al batch.
class _AccumulatingBanner extends StatelessWidget {
  const _AccumulatingBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('preview.accumulating'),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp3,
        0,
        AppTokens.sp3,
        AppTokens.sp2,
      ),
      child: Align(
        alignment: Alignment.center,
        child: Container(
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
              const Icon(
                Icons.hourglass_top,
                size: 16,
                color: AppTokens.primary,
              ),
              const SizedBox(width: AppTokens.sp2),
              Flexible(
                child: Text(
                  'Acumulando mensajes — el Asistente responderá al cerrar la ventana',
                  style: textTheme.labelMedium?.copyWith(
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.smart_toy_outlined,
              size: 40,
              color: AppTokens.text2,
            ),
            const SizedBox(height: AppTokens.sp3),
            Text(
              'Escríbele al Asistente como si fueras un cliente y observa cómo responde con su configuración actual.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final PreviewItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (item.isTool) {
      // Lectura del bot: chip discreto (sin acento) — diagnóstico, no
      // evento del negocio. El summary declara fallos ("falló…").
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp3,
            vertical: AppTokens.sp1,
          ),
          decoration: BoxDecoration(
            color: AppTokens.surface1,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: AppTokens.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(toolIconFor(item.tool), size: 14, color: AppTokens.text2),
              const SizedBox(width: AppTokens.sp2),
              Flexible(
                child: Text(
                  item.summary,
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (item.isAction) {
      // Efecto grabado del turno (etiquetaría/guardaría/ejecutaría): evento
      // centrado del hilo, con el idioma de cápsula del kit.
      return Align(
        alignment: Alignment.center,
        child: Container(
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
              Icon(
                toolIconFor(item.tool),
                size: 16,
                // El chip de error es el único con tinte de peligro: anuncia
                // un flush fallido, no un efecto grabado del bot.
                color: item.tool == 'error'
                    ? AppTokens.danger
                    : AppTokens.primary,
              ),
              const SizedBox(width: AppTokens.sp2),
              Flexible(
                child: Text(
                  item.summary,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppTokens.text1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (item.isMedia) {
      // Archivo que el flujo simulado enviaría: tipo legible + caption.
      // Burbuja del lado del bot — ES un envío del bot.
      return ChatBubble(
        key: const Key('preview.media_bubble'),
        mine: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _mediaIcon(item.stepType),
                  size: 18,
                  color: AppTokens.chatAccent,
                ),
                const SizedBox(width: AppTokens.sp2),
                Text(
                  _mediaLabel(item.stepType),
                  style: textTheme.labelMedium?.copyWith(
                    color: AppTokens.text1,
                  ),
                ),
              ],
            ),
            if (item.text.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppTokens.sp2),
              Text(
                item.text,
                style: textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
              ),
            ],
          ],
        ),
      );
    }
    return ChatBubble(
      mine: item.isUser,
      child: Text(
        item.text,
        style: textTheme.bodyLarge?.copyWith(color: AppTokens.text1),
      ),
    );
  }

  static IconData _mediaIcon(String stepType) => switch (stepType) {
    'IMAGE' => Icons.image_outlined,
    'VIDEO' => Icons.videocam_outlined,
    'DOCUMENT' => Icons.description_outlined,
    'AUDIO' => Icons.audiotrack_outlined,
    'PTT' => Icons.mic_none,
    'STICKER' => Icons.emoji_emotions_outlined,
    _ => Icons.attach_file,
  };

  static String _mediaLabel(String stepType) => switch (stepType) {
    'IMAGE' => 'Imagen',
    'VIDEO' => 'Video',
    'DOCUMENT' => 'Documento',
    'AUDIO' => 'Audio',
    'PTT' => 'Nota de voz',
    'STICKER' => 'Sticker',
    _ => 'Archivo',
  };
}
