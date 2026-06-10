import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          Container(
            key: const Key('preview.banner'),
            width: double.infinity,
            color: Theme.of(context).colorScheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Demo: nada se envía a WhatsApp. Las acciones aparecen como chips. Consume tokens reales.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: BlocBuilder<PreviewBloc, PreviewState>(
              builder: (context, state) => switch (state) {
                PreviewLoading() => const Center(
                  child: CircularProgressIndicator(),
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

class _PreviewThread extends StatefulWidget {
  const _PreviewThread({required this.state});

  final PreviewLoaded state;

  @override
  State<_PreviewThread> createState() => _PreviewThreadState();
}

class _PreviewThreadState extends State<_PreviewThread> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.state.sending) return;
    context.read<PreviewBloc>().add(PreviewMessageSent(text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      children: <Widget>[
        Expanded(
          child: s.items.isEmpty && !s.sending
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Escríbele al bot como si fueras un cliente y observa cómo responde con el entrenamiento actual.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: s.items.length + (s.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (s.sending && i == 0) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Escribiendo…'),
                        ),
                      );
                    }
                    final idx = s.items.length - 1 - (i - (s.sending ? 1 : 0));
                    return _ItemTile(item: s.items[idx]);
                  },
                ),
        ),
        if (s.failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              trainerFailureCopy(s.failure!),
              key: const Key('preview.failure'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('preview.composer.field'),
                    controller: _controller,
                    enabled: !s.sending,
                    decoration: const InputDecoration(
                      hintText: 'Escribe como cliente…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('preview.composer.send'),
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
    final scheme = Theme.of(context).colorScheme;
    if (item.isAction) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_actionIcon, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.summary,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final mine = item.isUser;
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
        child: Text(item.text),
      ),
    );
  }
}
