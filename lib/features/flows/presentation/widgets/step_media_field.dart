import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_media_thumb.dart';
import '../../../media/data/cache/caching_media_thumbnail_loader.dart';
import '../../../media/data/cache/dio_thumbnail_downloader.dart';
import '../../../media/data/cache/file_media_byte_store.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../../media/domain/repositories/media_byte_store.dart';
import '../../../media/domain/repositories/media_thumbnail_loader.dart';
import '../../domain/entities/step.dart' as fdom;
import '../media_step_name.dart';

/// Abre un selector de multimedia filtrado por [family] (image|video|audio|
/// document, o null = sin filtro) y devuelve el [MediaAsset] elegido, o `null`
/// si el usuario cancela. El caller persiste el ref BARE canónico
/// (`tenant/<org>/media/<id>[.<ext>]`) — JAMÁS la `previewUrl` firmada efímera —
/// y el filename del asset (para documentos). El `BuildContext` se pasa para que
/// el selector pueda navegar (p. ej. `context.push('/media/pick?type=<family>')`).
typedef MediaRefPicker =
    Future<MediaAsset?> Function(BuildContext context, String? family);

/// Familia de content-type por la que filtrar el picker, derivada del tipo
/// del paso. STICKER usa el contenedor de imagen; AUDIO/PTT comparten audio.
/// DOCUMENT no filtra (null): un paso documento envía cualquier archivo como
/// adjunto descargable, así que el picker ofrece toda la galería (p. ej. para
/// mandar un audio como documento). Los tipos sin media ⇒ null.
String? stepMediaFamilyFor(fdom.StepType type) => switch (type) {
  fdom.StepType.image || fdom.StepType.sticker => 'image',
  fdom.StepType.video => 'video',
  fdom.StepType.audio || fdom.StepType.ptt => 'audio',
  fdom.StepType.document ||
  fdom.StepType.text ||
  fdom.StepType.conditionalTime ||
  fdom.StepType.label ||
  fdom.StepType.end ||
  fdom.StepType.unsupported => null,
};

/// [AppMediaKind] a partir de una familia de content-type ('image'|'video'|
/// 'audio', o cualquier otra cosa ⇒ documento). Decide el glifo de respaldo
/// de la miniatura cuando no hay bytes que pintar.
AppMediaKind mediaKindForFamily(String? family) => switch (family) {
  'image' => AppMediaKind.image,
  'video' => AppMediaKind.video,
  'audio' => AppMediaKind.audio,
  _ => AppMediaKind.document,
};

/// Glifo de respaldo de la miniatura por tipo de paso multimedia. STICKER es
/// imagen; PTT comparte el glifo de audio. Sólo tiene sentido para los tipos
/// que llevan `mediaRef`; cualquier otro cae al genérico de documento.
AppMediaKind mediaKindForStepType(fdom.StepType type) => switch (type) {
  fdom.StepType.image || fdom.StepType.sticker => AppMediaKind.image,
  fdom.StepType.video => AppMediaKind.video,
  fdom.StepType.audio || fdom.StepType.ptt => AppMediaKind.audio,
  _ => AppMediaKind.document,
};

/// Resuelve los bytes de la miniatura de un paso multimedia a partir de su
/// `mediaRef` BARE, reusando el MISMO cache en disco que la galería (los bytes
/// de un ref son inmutables y el namespace es compartido).
///
/// Dos caminos, según lo que se tenga a mano:
/// - con el [MediaAsset] efímero del picker ⇒ el loader completo de la galería
///   (cache y, en un miss, descarga de la URL firmada del asset + persistencia);
/// - sólo el ref (paso hidratado de un flujo existente) ⇒ SOLO el cache: sin
///   asset no hay URL firmada y fabricarla localmente violaría el diseño. Un
///   miss cae al glifo — honesto: la miniatura aparece cuando la galería (o una
///   selección) la haya cacheado.
///
/// Nunca lanza: cualquier fallo (disco, plugin, red) es "sin miniatura" (null).
/// La URL firmada vive y muere dentro del loader; jamás sale de aquí.
class StepMediaThumbResolver {
  StepMediaThumbResolver({
    required MediaByteStore store,
    required MediaThumbnailLoader loader,
  }) : _store = store,
       _loader = loader;

  final MediaByteStore _store;
  final MediaThumbnailLoader _loader;

  /// Instancia de sesión con el cache real en disco. Vive aquí y no en el
  /// wiring central porque el árbol de flows no recibe el loader de la galería
  /// por constructor; el disco compartido (mismo namespace de bytes por ref)
  /// hace equivalentes ambas instancias. Los tests inyectan un fake.
  static final StepMediaThumbResolver session = () {
    final store = FileMediaByteStore();
    return StepMediaThumbResolver(
      store: store,
      loader: CachingMediaThumbnailLoader(
        store: store,
        download: DioThumbnailDownloader().call,
      ),
    );
  }();

  Future<Uint8List?> load(String ref, {MediaAsset? asset}) async {
    try {
      if (asset != null && asset.ref == ref) return await _loader.load(asset);
      return await _store.read(ref);
    } catch (_) {
      // Miniatura best-effort: sin bytes se pinta el glifo, nunca un error.
      return null;
    }
  }
}

/// Selector del recurso multimedia del step. El [controller] es la fuente de
/// verdad del `ref` BARE: el gate de submit y el evento de creación leen
/// `controller.text`, no este widget.
///
/// Sin ref: muestra un control tappable (`step_edit.media_picker`) que abre
/// la galería en modo picker vía [pickMediaRef] y guarda el ref devuelto. Con
/// ref: muestra un chip (`step_edit.media_selected`) con miniatura EFÍMERA del
/// recurso ([AppMediaThumb] vía [StepMediaThumbResolver]), el nombre legible
/// cuando se conoce (o la cola corta del ref en monospace como fallback) y un
/// botón "Cambiar" (`step_edit.media_change`) que reabre el picker.
///
/// El widget es read-only cuando [pickMediaRef] es `null` o cuando [enabled]
/// es false (mutación en vuelo): el control no abre nada y el chip no expone
/// "Cambiar". Lo ÚNICO persistido sigue siendo el ref BARE del controller; la
/// miniatura y el asset elegido son estado efímero de esta sesión del sheet.
class StepMediaField extends StatefulWidget {
  const StepMediaField({
    super.key,
    required this.controller,
    required this.pickMediaRef,
    required this.family,
    required this.onPicked,
    required this.enabled,
    this.thumbResolver,
  });

  final TextEditingController controller;
  final MediaRefPicker? pickMediaRef;

  /// Familia de content-type para filtrar la galería-picker (image|video|
  /// audio|document) según el tipo del paso; null ⇒ sin filtro.
  final String? family;

  /// Notifica al padre el asset elegido (para capturar su filename). El ref
  /// BARE va por el [controller]; este callback lleva el resto del asset.
  final ValueChanged<MediaAsset> onPicked;

  final bool enabled;

  /// Resolutor de bytes de la miniatura. `null` ⇒ el de sesión con el cache
  /// real en disco ([StepMediaThumbResolver.session]); los tests inyectan fakes.
  final StepMediaThumbResolver? thumbResolver;

  @override
  State<StepMediaField> createState() => _StepMediaFieldState();
}

class _StepMediaFieldState extends State<StepMediaField> {
  /// Asset elegido EN ESTA SESIÓN del sheet. Efímero a propósito: aporta la
  /// URL firmada para resolver la miniatura y el nombre legible, pero jamás se
  /// persiste (eso es el ref BARE del controller). Al hidratar un paso
  /// existente es null y la miniatura sólo puede salir del cache.
  MediaAsset? _picked;

  StepMediaThumbResolver get _resolver =>
      widget.thumbResolver ?? StepMediaThumbResolver.session;

  bool get _interactive => widget.enabled && widget.pickMediaRef != null;

  Future<void> _pick(BuildContext context) async {
    final picker = widget.pickMediaRef;
    if (picker == null) return;
    final asset = await picker(context, widget.family);
    if (asset == null) return;
    final ref = asset.ref.trim();
    if (ref.isEmpty) return;
    // Setear el texto dispara el listener del controller (en el padre), que
    // hace setState y re-renderiza con el chip seleccionado. El filename viaja
    // por onPicked. NUNCA se persiste asset.previewUrl (firmada efímera).
    widget.controller.text = ref;
    // Asignar `.text` deja la selección en offset -1 (inválida); enfocar el
    // campo seleccionaría todo. Colapsamos el caret al final para poder editar.
    widget.controller.selection = TextSelection.collapsed(offset: ref.length);
    if (mounted) setState(() => _picked = asset);
    widget.onPicked(asset);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ref = widget.controller.text.trim();
    if (ref.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recurso',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp2),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tonal(
              key: const Key('step_edit.media_picker'),
              label: 'Seleccionar multimedia',
              icon: Icons.perm_media_outlined,
              onPressed: _interactive ? () => _pick(context) : null,
            ),
          ),
        ],
      );
    }
    // El asset elegido sólo describe al ref vigente; si el controller trae
    // otro ref (hidratación, cambio externo), se ignora.
    final picked = _picked?.ref == ref ? _picked : null;
    // Con asset, el glifo de respaldo sale de su contentType real (un paso
    // documento puede llevar un audio); sin asset, de la familia del paso.
    final kind = picked != null
        ? _kindForContentType(picked.contentType)
        : mediaKindForFamily(widget.family);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recurso',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        Container(
          key: const Key('step_edit.media_selected'),
          padding: const EdgeInsets.all(AppTokens.sp3),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          ),
          child: Row(
            children: <Widget>[
              AppMediaThumb(
                // El key incluye si hay asset: cuando APARECE para el mismo
                // ref (re-selección tras hidratar) el remount re-resuelve con
                // la fuente nueva; el ref solo ya re-resuelve por sí mismo.
                key: ValueKey('step_edit.media_thumb.$ref#${picked != null}'),
                mediaRef: ref,
                kind: kind,
                size: 56,
                loader: (r) => _resolver.load(r, asset: picked),
              ),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Recurso seleccionado', style: textTheme.bodyMedium),
                    const SizedBox(height: AppTokens.sp1),
                    if (picked != null)
                      // Nombre legible del asset recién elegido (alias o
                      // filename): la verdad presentable de esta sesión.
                      Text(
                        picked.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTokens.text2,
                        ),
                      )
                    else
                      Text(
                        // Cola corta del ref (display-only, señal de id). La
                        // fuente de verdad sigue siendo el ref BARE completo
                        // en el controller.
                        shortMediaRef(ref),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTokens.text2,
                        ),
                      ),
                  ],
                ),
              ),
              if (_interactive)
                AppButton.text(
                  key: const Key('step_edit.media_change'),
                  label: 'Cambiar',
                  onPressed: () => _pick(context),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [AppMediaKind] desde un content-type concreto (`image/png`, `audio/ogg`…).
/// Familias no reconocidas caen a documento, el genérico de adjunto.
AppMediaKind _kindForContentType(String contentType) {
  if (contentType.startsWith('image/')) return AppMediaKind.image;
  if (contentType.startsWith('video/')) return AppMediaKind.video;
  if (contentType.startsWith('audio/')) return AppMediaKind.audio;
  return AppMediaKind.document;
}
