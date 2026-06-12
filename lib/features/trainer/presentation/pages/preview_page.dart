import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../../core/design/widgets/chat_bubble.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
import '../../domain/entities/preview_item.dart';
import '../bloc/preview_bloc.dart';
import 'trainer_chat_page.dart' show trainerFailureCopy;

/// Emulador del bot: corre el MISMO motor que producción contra una sesión
/// sandbox. Nada llega a WhatsApp; los efectos (etiquetas, notas, flujos)
/// aparecen como chips grabados. Consume tokens reales del proveedor.
class PreviewPage extends StatelessWidget {
  const PreviewPage({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Probar bot'),
        actions: <Widget>[
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
                PreviewLoaded() => _PreviewThread(state: state),
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
  const _PreviewThread({required this.state});

  final PreviewLoaded state;

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
    return Column(
      children: <Widget>[
        Expanded(
          child: s.items.isEmpty && !s.sending
              ? const _EmptyView()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(AppTokens.sp3),
                  itemCount: s.items.length + (s.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return const TypingBubble(key: Key('preview.typing'));
                    }
                    final idx = s.items.length - 1 - (i - (s.sending ? 1 : 0));
                    return _ItemTile(item: s.items[idx]);
                  },
                ),
        ),
        if (s.failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
            child: Text(
              trainerFailureCopy(s.failure!),
              key: const Key('preview.failure'),
              style: const TextStyle(color: AppTokens.danger),
            ),
          ),
        AppChatComposer(
          fieldKey: const Key('preview.composer.field'),
          sendKey: const Key('preview.composer.send'),
          hint: 'Escribe como cliente…',
          enabled: !s.sending,
          onSend: _send,
        ),
      ],
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
              'Escríbele al bot como si fueras un cliente y observa cómo responde con el entrenamiento actual.',
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

  IconData get _actionIcon => switch (item.tool) {
    'apply_label' => Icons.label_outline,
    'save_note' => Icons.sticky_note_2_outlined,
    'run_flow' => Icons.account_tree_outlined,
    'react' => Icons.add_reaction_outlined,
    'mark_read' => Icons.done_all,
    _ => Icons.bolt,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
              Icon(_actionIcon, size: 16, color: AppTokens.primary),
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
