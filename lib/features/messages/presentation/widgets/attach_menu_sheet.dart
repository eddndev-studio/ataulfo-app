import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';
import 'attach_gallery_sheet.dart';

/// Destino elegido en el menú de adjuntar del composer. El sheet sólo DECIDE;
/// el composer ejecuta el flujo (picker de archivos, galería de la
/// organización) con sus propias dependencias.
enum AttachMenuAction {
  /// Elegir archivos del dispositivo (el picker múltiple de siempre).
  document,

  /// Elegir un asset ya subido del catálogo de media de la organización.
  media,

  /// Capturar contenido nuevo con la cámara (foto o video; el llamador abre
  /// el sub-sheet que decide cuál).
  camera,
}

/// Resultado del menú de adjuntar: o un destino del grid de íconos, o una
/// selección confirmada de assets del carrete (cuando el sheet embebe la
/// previsualización de galería). Sellado para que el composer agote los
/// casos por switch.
sealed class AttachMenuResult {
  const AttachMenuResult();
}

/// Se tocó un destino del grid de íconos.
class AttachMenuDestination extends AttachMenuResult {
  const AttachMenuDestination(this.action);

  final AttachMenuAction action;
}

/// Se confirmó una selección múltiple del carrete («Adjuntar (n)»), en el
/// orden en que se tocaron las miniaturas. Los bytes NO viajan aquí: el
/// composer los pide bajo demanda con [DeviceGalleryPort.bytesFor].
class AttachMenuGalleryPick extends AttachMenuResult {
  const AttachMenuGalleryPick(this.assets);

  final List<DeviceMediaAsset> assets;
}

/// Menú de adjuntar del composer del hilo (estilo WhatsApp): una fila de
/// destinos tappeables —ícono + etiqueta— que cierra devolviendo el
/// [AttachMenuResult] elegido, o `null` si se descarta.
///
/// Con un carrete accesible ([DeviceGalleryPort]) la presentación cambia a
/// [AttachGallerySheet]: el mismo grid de íconos arriba y una grilla de
/// fotos/videos recientes debajo, visible desde que el sheet abre y que crece
/// al arrastrar la manija. Sin carrete, este widget es el sheet completo:
/// stateless y sin dependencias — decidir el destino es lo ÚNICO que hace.
class AttachMenuSheet extends StatelessWidget {
  const AttachMenuSheet({super.key, this.showCamera = false});

  /// Ofrecer el destino Cámara. El llamador lo resuelve con
  /// `CameraCapture.isSupported()` ANTES de abrir: así el sheet sigue
  /// stateless y sin dependencias (sin botón muerto donde no hay cámara).
  final bool showCamera;

  /// Abre el menú y resuelve con lo elegido, o `null` si se cierra sin
  /// elegir. Con [gallery] no-nulo (carrete soportado, resuelto por el
  /// llamador con `isSupported()` ANTES de abrir) la hoja es expandible y
  /// embebe la previsualización del carrete debajo del grid de íconos.
  static Future<AttachMenuResult?> open(
    BuildContext context, {
    bool showCamera = false,
    DeviceGalleryPort? gallery,
  }) {
    if (gallery == null) {
      return showAppBottomSheet<AttachMenuResult>(
        context,
        backgroundColor: AppTokens.surface1,
        builder: (_) => AttachMenuSheet(showCamera: showCamera),
      );
    }
    // La manija del modal se apaga: la hoja expandible pinta la suya propia,
    // cableada a redimensionar el DraggableScrollableSheet (no a descartar).
    return showAppBottomSheet<AttachMenuResult>(
      context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AttachGallerySheet(gallery: gallery, showCamera: showCamera),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const Key('attach_menu_sheet'),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.sheetBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Adjuntar', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp4),
          AttachMenuRow(showCamera: showCamera),
        ],
      ),
    );
  }
}

/// El grid de íconos del menú de adjuntar: Documento y Medios siempre;
/// Cámara y Galería sólo cuando el llamador las habilita (soporte real).
/// Documento/Medios/Cámara cierran el sheet devolviendo su
/// [AttachMenuDestination]; Galería NO cierra — dispara [onGallery] (la hoja
/// expandible lo cablea a crecer a pantalla completa).
class AttachMenuRow extends StatelessWidget {
  const AttachMenuRow({
    super.key,
    this.showCamera = false,
    this.showGallery = false,
    this.onGallery,
  });

  final bool showCamera;
  final bool showGallery;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    // Columnas iguales (Expanded) en vez de gaps fijos: hasta 4 destinos
    // caben en un ancho de teléfono sin desbordar, distribuidos parejo como
    // en la referencia.
    return Row(
      children: <Widget>[
        const Expanded(
          child: _AttachMenuItem(
            key: Key('attach_menu.document'),
            action: AttachMenuAction.document,
            icon: Icons.insert_drive_file_outlined,
            label: 'Documento',
          ),
        ),
        const Expanded(
          child: _AttachMenuItem(
            key: Key('attach_menu.media'),
            action: AttachMenuAction.media,
            icon: Icons.perm_media_outlined,
            label: 'Medios',
          ),
        ),
        if (showCamera)
          const Expanded(
            child: _AttachMenuItem(
              key: Key('attach_menu.camera'),
              action: AttachMenuAction.camera,
              icon: Icons.camera_alt_outlined,
              label: 'Cámara',
            ),
          ),
        if (showGallery)
          Expanded(
            child: _AttachMenuItem(
              key: const Key('attach_menu.gallery'),
              icon: Icons.photo_library_outlined,
              label: 'Galería',
              onTap: onGallery,
            ),
          ),
      ],
    );
  }
}

/// Un destino del menú: círculo con ícono + etiqueta debajo. Con [action],
/// tocar cierra el sheet devolviéndola como [AttachMenuDestination]; si no,
/// tocar dispara [onTap] (el destino vive dentro del sheet, como Galería).
class _AttachMenuItem extends StatelessWidget {
  const _AttachMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.action,
    this.onTap,
  }) : assert(
         (action != null) ^ (onTap != null),
         'o cierra con action o maneja el tap, nunca ambos',
       );

  final AttachMenuAction? action;
  final VoidCallback? onTap;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final popAction = action;
    return InkWell(
      onTap: popAction != null
          ? () => Navigator.of(context).pop(AttachMenuDestination(popAction))
          : onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTokens.surface3,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp2),
            // El label se ENCOGE si su columna queda angosta (4 destinos en
            // un teléfono) en vez de desbordar o cortarse con elipsis.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
