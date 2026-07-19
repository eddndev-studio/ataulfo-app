import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../bloc/sticker_cubit.dart';

/// Selector de stickers para el chat: muestra los stickers corporativos LISTOS
/// de la org y, al tocar uno, cierra devolviendo su ref de galería (el composer
/// lo envía al instante). [resolveThumb] entrega los bytes por ref; cualquier
/// fallo ⇒ null (placeholder), nunca un error. A diferencia de la pantalla de
/// Ajustes, aquí no se generan stickers: solo se eligen los ya hechos.
class StickerPickerPage extends StatelessWidget {
  const StickerPickerPage({required this.resolveThumb, super.key});

  final Future<Uint8List?> Function(String ref) resolveThumb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar sticker')),
      body: BlocBuilder<StickerCubit, StickerState>(
        builder: (context, state) {
          return switch (state.status) {
            StickerListStatus.loading => const AppLoadingIndicator(),
            StickerListStatus.error => AppErrorState(
              message: 'No se pudieron cargar tus stickers.',
              onRetry: () => context.read<StickerCubit>().load(),
            ),
            StickerListStatus.loaded => _Grid(
              refs: <String>[for (final j in state.ready) j.resultMediaRef],
              resolveThumb: resolveThumb,
            ),
          };
        },
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.refs, required this.resolveThumb});

  final List<String> refs;
  final Future<Uint8List?> Function(String ref) resolveThumb;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no tienes stickers. Genéralos en Ajustes › Stickers.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final ref in refs) _PickCell(ref: ref, resolveThumb: resolveThumb),
      ],
    );
  }
}

/// Una celda seleccionable: carga el thumbnail transparente y al tocar cierra
/// el picker con el ref. Muestra un placeholder mientras resuelve o si falla.
class _PickCell extends StatefulWidget {
  const _PickCell({required this.ref, required this.resolveThumb});

  final String ref;
  final Future<Uint8List?> Function(String ref) resolveThumb;

  @override
  State<_PickCell> createState() => _PickCellState();
}

class _PickCellState extends State<_PickCell> {
  Uint8List? _bytes;

  /// El thumbnail ya terminó de resolver (con bytes o con null). Sin esta
  /// marca, una resolución a null dejaría el spinner girando para siempre: hay
  /// que distinguir «aún cargando» de «resolvió y no hay imagen».
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
    return InkWell(
      key: Key('sticker_pick.${widget.ref}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      onTap: () => Navigator.of(context).pop(widget.ref),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        child: bytes != null
            ? Padding(
                padding: const EdgeInsets.all(6),
                child: Image.memory(bytes, fit: BoxFit.contain),
              )
            : Center(
                child: _tried
                    ? Icon(
                        Icons.emoji_emotions_outlined,
                        size: 22,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
      ),
    );
  }
}
