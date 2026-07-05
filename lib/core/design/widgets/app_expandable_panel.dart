import 'package:flutter/material.dart';

import '../tokens.dart';

/// Hoja expandible del design system (estilo panel de adjuntar de WhatsApp):
/// una superficie anclada abajo, con manija propia, que crece hacia arriba al
/// arrastrar y se auto-descarta al llegar al mínimo.
///
/// La mecánica: un [DraggableScrollableSheet] acopla el scroll del [builder]
/// (contenido scrolleable) a la altura de la hoja —arrastrar el contenido hacia
/// arriba primero agranda la hoja, luego scrollea— y la manija arrastra la misma
/// altura vía el controller. El [headerBuilder] pinta contenido FIJO bajo la
/// manija (no scrollea) y recibe un callback `expand` para agrandar la hoja al
/// máximo de un solo gesto. Cruzar el mínimo dispara [onDismissed] (el dueño
/// decide qué es descartar: cerrar el panel, hacer pop, etc.).
///
/// Sólo la mecánica: el fondo, la forma y el contenido los aporta el llamador.
class AppExpandablePanel extends StatefulWidget {
  const AppExpandablePanel({
    super.key,
    required this.builder,
    required this.onDismissed,
    this.headerBuilder,
    this.initialSize = 0.45,
    this.minSize = 0.30,
    this.maxSize = 0.95,
    this.backgroundColor = AppTokens.surface1,
    this.handleKey,
  });

  /// Contenido scrolleable de la hoja. Recibe el [ScrollController] del sheet:
  /// úsalo en el scrollable para que arrastrarlo acople scroll y altura.
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// Se llama cuando la hoja se arrastra por debajo del mínimo (auto-descarte).
  final VoidCallback onDismissed;

  /// Contenido FIJO bajo la manija (no scrollea). Recibe `expand`, que agranda
  /// la hoja al máximo de un gesto (p. ej. un botón "ver todo").
  final Widget Function(BuildContext context, VoidCallback expand)?
  headerBuilder;

  /// Fracciones del alto disponible: inicial, mínima (auto-descarte) y máxima.
  final double initialSize;
  final double minSize;
  final double maxSize;

  final Color backgroundColor;

  /// Key de la manija, para localizarla en tests.
  final Key? handleKey;

  @override
  State<AppExpandablePanel> createState() => _AppExpandablePanelState();
}

class _AppExpandablePanelState extends State<AppExpandablePanel> {
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// Evita disparar dos descartes si la notificación de altura mínima re-entra
  /// mientras el dueño ya está cerrando.
  bool _dismissed = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _expand() {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      widget.maxSize,
      duration: AppTokens.durationSlow,
      curve: AppTokens.ease,
    );
  }

  /// Arrastrar la manija redimensiona la hoja 1:1 con el dedo (delta en
  /// píxeles → fracción del alto disponible). El clamp mantiene el gesto dentro
  /// de los límites; llegar al mínimo dispara el descarte de abajo.
  void _dragHandle(DragUpdateDetails details, double maxHeight) {
    if (!_sheet.isAttached || maxHeight <= 0) return;
    final next = (_sheet.size - details.delta.dy / maxHeight).clamp(
      widget.minSize,
      widget.maxSize,
    );
    _sheet.jumpTo(next);
  }

  bool _onNotification(DraggableScrollableNotification notification) {
    if (!_dismissed && notification.extent <= notification.minExtent + 0.005) {
      _dismissed = true;
      widget.onDismissed();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          NotificationListener<DraggableScrollableNotification>(
            onNotification: _onNotification,
            child: DraggableScrollableSheet(
              controller: _sheet,
              expand: false,
              initialChildSize: widget.initialSize,
              minChildSize: widget.minSize,
              maxChildSize: widget.maxSize,
              builder: (context, scrollController) => DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTokens.radiusCard),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    _Handle(
                      key: widget.handleKey,
                      onDrag: (details) =>
                          _dragHandle(details, constraints.maxHeight),
                    ),
                    if (widget.headerBuilder != null)
                      widget.headerBuilder!(context, _expand),
                    Expanded(child: widget.builder(context, scrollController)),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

/// La manija de la hoja: a diferencia de la del modal (que descarta), ésta
/// REDIMENSIONA —el gesto vertical viaja al controller del sheet—. Zona de
/// toque generosa (padding opaco) para que no exija puntería.
class _Handle extends StatelessWidget {
  const _Handle({super.key, required this.onDrag});

  final void Function(DragUpdateDetails details) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
