import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_swatch_icon.dart';

/// Un destino/acción del panel de adjuntar: círculo neutro del kit con un
/// ícono + etiqueta debajo. Tocar dispara [onTap]. Vocabulario visual único
/// del panel —lo comparten la fila de destinos y la sub-vista de cámara—.
class AttachTile extends StatelessWidget {
  const AttachTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // El círculo canónico del kit (tamaño sp9 = 56).
            AppSwatchIcon.neutral(icon: icon, size: AppTokens.sp9),
            const SizedBox(height: AppTokens.sp2),
            // El label se ENCOGE si su columna queda angosta (varios destinos
            // en un teléfono) en vez de desbordar o cortarse con elipsis.
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

/// La fila de destinos del panel de adjuntar: Documento y Medios siempre;
/// Cámara y Galería sólo cuando el llamador las habilita (soporte real, para
/// no ofrecer un destino muerto). Cada destino dispara su callback; el panel
/// decide qué hace cada uno (elegir + cerrar, cambiar de vista, o expandir).
class AttachMenuRow extends StatelessWidget {
  const AttachMenuRow({
    super.key,
    required this.onDocument,
    required this.onMedia,
    this.onCamera,
    this.onGallery,
  });

  final VoidCallback onDocument;
  final VoidCallback onMedia;

  /// Destino Cámara; `null` ⇒ no se ofrece (plataforma sin cámara).
  final VoidCallback? onCamera;

  /// Destino Galería; `null` ⇒ no se ofrece (carrete no soportado).
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    // Columnas iguales (Expanded): hasta 4 destinos caben en el ancho de un
    // teléfono sin desbordar, distribuidos parejo como en la referencia.
    return Row(
      children: <Widget>[
        Expanded(
          child: AttachTile(
            key: const Key('attach_menu.document'),
            icon: Icons.insert_drive_file_outlined,
            label: 'Documento',
            onTap: onDocument,
          ),
        ),
        Expanded(
          child: AttachTile(
            key: const Key('attach_menu.media'),
            icon: Icons.perm_media_outlined,
            label: 'Medios',
            onTap: onMedia,
          ),
        ),
        if (onCamera != null)
          Expanded(
            child: AttachTile(
              key: const Key('attach_menu.camera'),
              icon: Icons.camera_alt_outlined,
              label: 'Cámara',
              onTap: onCamera,
            ),
          ),
        if (onGallery != null)
          Expanded(
            child: AttachTile(
              key: const Key('attach_menu.gallery'),
              icon: Icons.photo_library_outlined,
              // Carrete LOCAL del dispositivo — distinto del catálogo de la
              // org ("Medios"); "Galería" a secas confundía ambos destinos.
              label: 'Fotos del dispositivo',
              onTap: onGallery,
            ),
          ),
      ],
    );
  }
}
