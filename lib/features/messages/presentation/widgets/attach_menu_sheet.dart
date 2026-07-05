import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';

/// Destino elegido en el menú de adjuntar del composer. El sheet sólo DECIDE;
/// el composer ejecuta el flujo (picker de archivos, galería de la
/// organización) con sus propias dependencias.
enum AttachMenuAction {
  /// Elegir archivos del dispositivo (el picker múltiple de siempre).
  document,

  /// Elegir un asset ya subido del catálogo de media de la organización.
  media,
}

/// Menú de adjuntar del composer del hilo (estilo WhatsApp): una fila de
/// destinos tappeables —ícono + etiqueta— que cierra devolviendo la
/// [AttachMenuAction] elegida, o `null` si se descarta.
///
/// Stateless y sin dependencias: decidir el destino es lo ÚNICO que hace.
/// Ejecutar cada flujo queda en el llamador, que sí tiene los repos y el
/// router a mano — así el sheet no arrastra providers a la ruta modal.
class AttachMenuSheet extends StatelessWidget {
  const AttachMenuSheet({super.key});

  /// Abre el menú y resuelve con el destino elegido, o `null` si se cierra
  /// sin elegir.
  static Future<AttachMenuAction?> open(BuildContext context) {
    return showAppBottomSheet<AttachMenuAction>(
      context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => const AttachMenuSheet(),
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
          const Row(
            children: <Widget>[
              _AttachMenuItem(
                key: Key('attach_menu.document'),
                action: AttachMenuAction.document,
                icon: Icons.insert_drive_file_outlined,
                label: 'Documento',
              ),
              SizedBox(width: AppTokens.sp4),
              _AttachMenuItem(
                key: Key('attach_menu.media'),
                action: AttachMenuAction.media,
                icon: Icons.perm_media_outlined,
                label: 'Medios',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un destino del menú: círculo con ícono + etiqueta debajo. Tocar cierra el
/// sheet devolviendo su [action].
class _AttachMenuItem extends StatelessWidget {
  const _AttachMenuItem({
    super.key,
    required this.action,
    required this.icon,
    required this.label,
  });

  final AttachMenuAction action;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
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
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
      ),
    );
  }
}
