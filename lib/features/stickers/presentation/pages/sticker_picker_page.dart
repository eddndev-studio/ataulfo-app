import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../bloc/sticker_cubit.dart';

/// Selector de stickers para el chat: muestra los stickers corporativos LISTOS
/// de la org y, al tocar uno, cierra devolviendo su ref de galería (el composer
/// lo envía al instante). [resolveThumb] entrega los bytes por ref; cualquier
/// fallo ⇒ null (placeholder), nunca un error. A diferencia de la pantalla de
/// Ajustes, aquí no se generan stickers: solo se eligen los ya hechos.
class StickerPickerPage extends StatelessWidget {
  const StickerPickerPage({
    required this.resolveThumb,
    this.canManage = false,
    super.key,
  });

  final Future<Uint8List?> Function(String ref) resolveThumb;
  final bool canManage;

  Future<void> _manage(BuildContext context) async {
    await context.push<void>('/org/stickers');
    if (context.mounted) await context.read<StickerCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar sticker'),
        actions: <Widget>[
          if (canManage)
            IconButton(
              key: const Key('sticker_picker.manage'),
              tooltip: 'Crear y administrar stickers',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => unawaited(_manage(context)),
            ),
        ],
      ),
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
              onManage: canManage ? () => _manage(context) : null,
            ),
          };
        },
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.refs, required this.resolveThumb, this.onManage});

  final List<String> refs;
  final Future<Uint8List?> Function(String ref) resolveThumb;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    if (refs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Aún no hay stickers listos para enviar.',
                textAlign: TextAlign.center,
              ),
              if (onManage != null) ...<Widget>[
                const SizedBox(height: AppTokens.sp4),
                AppButton.tonal(
                  key: const Key('sticker_picker.empty.manage'),
                  label: 'Crear stickers',
                  onPressed: onManage,
                ),
              ],
            ],
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
