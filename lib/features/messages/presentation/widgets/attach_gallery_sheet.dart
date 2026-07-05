import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../media/domain/repositories/device_gallery_port.dart';
import 'attach_gallery_picker.dart';
import 'attach_menu_sheet.dart';

/// La variante expandible del menú de adjuntar (estilo WhatsApp), usada
/// cuando el carrete del dispositivo es accesible: manija propia + grid de
/// íconos FIJO arriba + la grilla de fotos/videos recientes debajo, visible
/// desde que abre.
///
/// La previsualización crece SIN salir del sheet: un
/// [DraggableScrollableSheet] acopla el scroll de la grilla a la altura de la
/// hoja (arrastrar la grilla hacia arriba primero agranda la hoja, luego
/// scrollea), y la manija arrastra la misma altura vía el controller. Tocar
/// el ícono Galería expande a la altura máxima de un solo gesto. Llegar a la
/// altura mínima descarta la hoja (como arrastrar el menú simple hacia
/// abajo).
class AttachGallerySheet extends StatefulWidget {
  const AttachGallerySheet({
    super.key,
    required this.gallery,
    this.showCamera = false,
  });

  /// Carrete YA resuelto como soportado por el llamador (`isSupported()`).
  final DeviceGalleryPort gallery;

  /// Ofrecer el destino Cámara (mismo contrato que [AttachMenuSheet]).
  final bool showCamera;

  /// Altura inicial: grid de íconos + 2-3 filas de miniaturas.
  static const double initialSize = 0.45;

  /// Por debajo de esta fracción la hoja se descarta.
  static const double minSize = 0.30;

  /// Altura expandida: la grilla casi a pantalla completa, dentro del sheet.
  static const double maxSize = 0.95;

  @override
  State<AttachGallerySheet> createState() => _AttachGallerySheetState();
}

class _AttachGallerySheetState extends State<AttachGallerySheet> {
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// Evita despachar dos pops si la notificación de altura mínima re-entra
  /// mientras la ruta ya está saliendo.
  bool _popped = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _expand() {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      AttachGallerySheet.maxSize,
      duration: AppTokens.durationSlow,
      curve: AppTokens.ease,
    );
  }

  /// Arrastrar la manija redimensiona la hoja 1:1 con el dedo (delta en
  /// píxeles → fracción del alto disponible). El clamp mantiene el gesto
  /// dentro de los límites; llegar al mínimo dispara el pop de abajo.
  void _dragHandle(DragUpdateDetails details, double maxHeight) {
    if (!_sheet.isAttached || maxHeight <= 0) return;
    final next = (_sheet.size - details.delta.dy / maxHeight).clamp(
      AttachGallerySheet.minSize,
      AttachGallerySheet.maxSize,
    );
    _sheet.jumpTo(next);
  }

  bool _onSheetNotification(DraggableScrollableNotification notification) {
    if (!_popped && notification.extent <= notification.minExtent + 0.005) {
      _popped = true;
      Navigator.of(context).pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          NotificationListener<DraggableScrollableNotification>(
            onNotification: _onSheetNotification,
            child: DraggableScrollableSheet(
              controller: _sheet,
              expand: false,
              initialChildSize: AttachGallerySheet.initialSize,
              minChildSize: AttachGallerySheet.minSize,
              maxChildSize: AttachGallerySheet.maxSize,
              builder: (context, scrollController) => Container(
                key: const Key('attach_gallery_sheet'),
                decoration: const BoxDecoration(
                  color: AppTokens.surface1,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTokens.radiusCard),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    _Handle(
                      onDrag: (details) =>
                          _dragHandle(details, constraints.maxHeight),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.sp6,
                        0,
                        AppTokens.sp6,
                        AppTokens.sp3,
                      ),
                      child: AttachMenuRow(
                        showCamera: widget.showCamera,
                        showGallery: true,
                        onGallery: _expand,
                      ),
                    ),
                    Expanded(
                      child: AttachGalleryPicker(
                        gallery: widget.gallery,
                        scrollController: scrollController,
                        onConfirm: (assets) => Navigator.of(
                          context,
                        ).pop(AttachMenuGalleryPick(assets)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

/// La manija de la hoja expandible. A diferencia de la manija del modal
/// (que descarta), ésta REDIMENSIONA: el gesto vertical viaja al
/// [DraggableScrollableController] del sheet. Zona de toque generosa
/// (padding opaco) para que el gesto no exija puntería.
class _Handle extends StatelessWidget {
  const _Handle({required this.onDrag});

  final void Function(DragUpdateDetails details) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('attach_gallery.handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onDrag,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTokens.text2,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
        ),
      ),
    );
  }
}
