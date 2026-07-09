import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sticker_job.dart';
import '../bloc/sticker_cubit.dart';
import '../sticker_copy.dart';
import '../sticker_motifs.dart';

/// Pantalla de stickers corporativos: el operador genera un sticker eligiendo
/// un motivo curado y ve su galería (en curso, listos y fallidos). Los listos
/// se pueden usar en el chat. [resolveThumb] entrega los bytes del sticker por
/// su ref (galería); cualquier fallo ⇒ null (placeholder), nunca un error.
class StickersPage extends StatelessWidget {
  const StickersPage({required this.resolveThumb, super.key});

  final Future<Uint8List?> Function(String ref) resolveThumb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stickers')),
      body: BlocBuilder<StickerCubit, StickerState>(
        builder: (context, state) {
          return switch (state.status) {
            StickerListStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            StickerListStatus.error => _ErrorView(
              onRetry: () => context.read<StickerCubit>().load(),
            ),
            StickerListStatus.loaded => _Loaded(
              state: state,
              resolveThumb: resolveThumb,
            ),
          };
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudieron cargar tus stickers.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state, required this.resolveThumb});

  final StickerState state;
  final Future<Uint8List?> Function(String ref) resolveThumb;

  Future<void> _generate(BuildContext context, String motif) async {
    final cubit = context.read<StickerCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final failure = await cubit.generate(motif);
    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(stickerFailureCopy(failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Genera un sticker',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Elige un motivo y la IA lo dibuja con el fondo transparente listo '
          'para el chat.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in stickerMotifs)
              ActionChip(
                avatar: Icon(m.icon, size: 18),
                label: Text(m.label),
                onPressed: state.generating
                    ? null
                    : () => _generate(context, m.id),
              ),
          ],
        ),
        if (state.generating) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Encolando…'),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Tus stickers', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (state.jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Aún no tienes stickers.')),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final j in state.jobs)
                _StickerCell(job: j, resolveThumb: resolveThumb),
            ],
          ),
      ],
    );
  }
}

/// Una celda del grid: el sticker listo (thumbnail transparente), un spinner
/// mientras se genera, o un aviso si falló.
class _StickerCell extends StatelessWidget {
  const _StickerCell({required this.job, required this.resolveThumb});

  final StickerJob job;
  final Future<Uint8List?> Function(String ref) resolveThumb;

  @override
  Widget build(BuildContext context) {
    final label = stickerMotifLabel(job.motif);
    return switch (job.status) {
      StickerStatus.done when job.resultMediaRef.isNotEmpty => _Thumb(
        ref: job.resultMediaRef,
        label: label,
        resolveThumb: resolveThumb,
      ),
      StickerStatus.failed => _Placeholder(
        icon: Icons.error_outline,
        label: label,
        tooltip: job.errorNote,
      ),
      _ => const _Placeholder(icon: null, label: 'Generando…', tooltip: null),
    };
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({
    required this.ref,
    required this.label,
    required this.resolveThumb,
  });

  final String ref;
  final String label;
  final Future<Uint8List?> Function(String ref) resolveThumb;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  Uint8List? _bytes;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    widget.resolveThumb(widget.ref).then((b) {
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _tried = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Tooltip(
        message: widget.label,
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    }
    return _Placeholder(
      icon: _tried ? Icons.emoji_emotions_outlined : null,
      label: widget.label,
      tooltip: null,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  final IconData? icon;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: icon == null
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
      ),
    );
    return tooltip == null
        ? content
        : Tooltip(message: tooltip, child: content);
  }
}
