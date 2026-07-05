import 'package:flutter/material.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';

/// Modo de captura elegido en el sub-sheet de cámara.
enum CameraCaptureMode {
  /// Abrir la cámara en modo foto.
  photo,

  /// Abrir la cámara en modo video.
  video,
}

/// Sub-sheet del destino Cámara del menú de adjuntar: dos filas explícitas
/// (foto / video, sin gestos ocultos) que cierran devolviendo el
/// [CameraCaptureMode] elegido, o `null` si se descarta.
///
/// Igual que [AttachMenuSheet]: stateless y sin dependencias — decidir el
/// modo es lo ÚNICO que hace; capturar queda en el llamador, que tiene el
/// `CameraCapture` a mano.
class AttachCameraSheet extends StatelessWidget {
  const AttachCameraSheet({super.key});

  /// Abre el sub-sheet y resuelve con el modo elegido, o `null` si se cierra
  /// sin elegir.
  static Future<CameraCaptureMode?> open(BuildContext context) {
    return showAppBottomSheet<CameraCaptureMode>(
      context,
      backgroundColor: AppTokens.surface1,
      builder: (_) => const AttachCameraSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('attach_camera_sheet'),
      padding: EdgeInsets.only(bottom: context.sheetBottomInset),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CameraModeRow(
            key: Key('attach_menu.camera.photo'),
            mode: CameraCaptureMode.photo,
            icon: Icons.photo_camera_outlined,
            label: 'Tomar foto',
          ),
          _CameraModeRow(
            key: Key('attach_menu.camera.video'),
            mode: CameraCaptureMode.video,
            icon: Icons.videocam_outlined,
            label: 'Grabar video',
          ),
        ],
      ),
    );
  }
}

/// Una fila del sub-sheet: ícono + etiqueta. Tocar cierra el sheet
/// devolviendo su [mode].
class _CameraModeRow extends StatelessWidget {
  const _CameraModeRow({
    super.key,
    required this.mode,
    required this.icon,
    required this.label,
  });

  final CameraCaptureMode mode;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).pop(mode),
      leading: Icon(icon, color: AppTokens.text2),
      title: Text(label),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp6),
    );
  }
}
