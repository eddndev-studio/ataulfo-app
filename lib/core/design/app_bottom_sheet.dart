import 'package:flutter/material.dart';

import 'app_confirm_dialog.dart';

/// Key del botón que confirma el descarte en el diálogo del guard, para que
/// las pruebas de los sheets consumidores lo anclen sin depender del label.
const Key appSheetDiscardConfirmKey = Key('app_sheet.discard.confirm');

/// Key del botón que cancela el descarte y conserva la hoja abierta.
const Key appSheetDiscardCancelKey = Key('app_sheet.discard.cancel');

/// Key del drag handle propio de las hojas con guard de descarte.
const Key appSheetDragHandleKey = Key('app_sheet.drag_handle');

/// Punto único para abrir hojas inferiores en la app. Envuelve
/// [showModalBottomSheet] forzando `useSafeArea: true`, que mantiene la hoja
/// por debajo de la barra de estado del sistema (notificaciones, batería,
/// señal): sin él, una hoja con mucho contenido vertical
/// (`isScrollControlled: true`) crece hasta el borde superior de la pantalla y
/// pinta detrás de esas barras.
///
/// También muestra el `dragHandle` (la manija superior) y mantiene
/// `enableDrag`, para que la hoja se cierre arrastrándola hacia abajo desde la
/// manija: el contenido de las hojas es un `SingleChildScrollView` que captura
/// el gesto vertical, así que sin esa zona dedicada no quedaría forma de
/// descartar más que el botón "atrás".
///
/// El resto de parámetros se reflejan tal cual de [showModalBottomSheet] y sus
/// defaults coinciden con los suyos, así que es un reemplazo directo: cada
/// llamador conserva su comportamiento (scroll, color de fondo) y solo gana la
/// protección del área segura. `useSafeArea` solo afecta arriba/izquierda/
/// derecha (`bottom: false`), de modo que el inset inferior del teclado y de la
/// gesture-nav lo siguen manejando las hojas con su propio `sheetBottomInset`.
///
/// **Guard de descarte.** [confirmDiscard] no nulo convierte la hoja en un
/// formulario protegido: ante cualquier intento de DESCARTE (tap en el scrim,
/// arrastre del handle hacia abajo, back físico) se consulta el callback y,
/// si devuelve `true` (hay cambios sin guardar), se muestra el
/// [showAppConfirmDialog] canónico «¿Descartar los cambios?» — la hoja solo
/// se cierra si el operador confirma. Con `false` el descarte procede
/// directo. El cierre programático (`Navigator.pop(context, resultado)`, el
/// camino feliz de Guardar) NUNCA pasa por el guard.
///
/// [canDismiss] permite bloquear temporalmente cualquier descarte (por ejemplo,
/// mientras una petición está en vuelo). Si devuelve `false`, scrim, back y
/// handle no cierran la hoja ni abren el diálogo de confirmación. Al omitirse
/// conserva el comportamiento previo.
///
/// La hoja guardada pinta un handle propio (misma geometría y color que el de
/// Material) porque el de serie cierra la ruta con un pop incondicional que
/// ningún guard puede vetar; a cambio, el arrastre del handle no acompaña al
/// dedo — al soltar con intención de cierre se dispara el guard y la hoja se
/// despide con su animación normal. Sin [confirmDiscard] el comportamiento es
/// EXACTAMENTE el previo.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  bool showDragHandle = true,
  bool Function()? confirmDiscard,
  bool Function()? canDismiss,
}) {
  if (confirmDiscard == null && canDismiss == null) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    // El handle y el arrastre de serie cierran con un pop incondicional que
    // saltaría el guard: la hoja guardada trae su propio handle, cuyo gesto
    // pasa por maybePop y por lo tanto por el PopScope del guard.
    showDragHandle: false,
    enableDrag: false,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    builder: (sheetContext) => _GuardedSheet(
      confirmDiscard: confirmDiscard ?? () => false,
      canDismiss: canDismiss ?? () => true,
      showDragHandle: showDragHandle,
      child: builder(sheetContext),
    ),
  );
}

/// Envoltura de una hoja con guard de descarte: un [PopScope] que retiene
/// todo pop por `maybePop` (scrim, back físico, handle propio) y decide con
/// [confirmDiscard] si procede directo o exige confirmación.
class _GuardedSheet extends StatefulWidget {
  const _GuardedSheet({
    required this.confirmDiscard,
    required this.canDismiss,
    required this.showDragHandle,
    required this.child,
  });

  final bool Function() confirmDiscard;
  final bool Function() canDismiss;
  final bool showDragHandle;
  final Widget child;

  @override
  State<_GuardedSheet> createState() => _GuardedSheetState();
}

class _GuardedSheetState extends State<_GuardedSheet> {
  /// Evita apilar diálogos si llegan varios intentos de descarte mientras la
  /// confirmación sigue abierta (drag + back en rápida sucesión).
  bool _confirming = false;

  /// Todo gesto de descarte desemboca aquí vía `maybePop`, que consulta el
  /// [PopScope] de abajo en vez de cerrar incondicionalmente.
  void _requestDismiss() {
    Navigator.of(context).maybePop();
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || _confirming) {
      return;
    }
    if (!widget.canDismiss()) {
      return;
    }
    if (!widget.confirmDiscard()) {
      Navigator.of(context).pop(result);
      return;
    }
    _confirming = true;
    try {
      final discard = await showAppConfirmDialog(
        context,
        title: '¿Descartar los cambios?',
        confirmLabel: 'Descartar',
        confirmKey: appSheetDiscardConfirmKey,
        cancelKey: appSheetDiscardCancelKey,
      );
      if (discard && mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Misma anatomía que la hoja de serie con handle: el handle flota sobre
    // el contenido, que reserva su alto con un padding superior.
    final child = !widget.showDragHandle
        ? widget.child
        : Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              _GuardedDragHandle(onDismissIntent: _requestDismiss),
              Padding(
                padding: const EdgeInsets.only(top: kMinInteractiveDimension),
                child: widget.child,
              ),
            ],
          );

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: child,
    );
  }
}

/// Handle de arrastre de las hojas guardadas. Replica la geometría y el color
/// del de Material (caja táctil de 48px con la barrita de 32×4 del tema) pero
/// su gesto emite una INTENCIÓN de descarte en vez de cerrar la ruta: soltar
/// tras un arrastre descendente decidido (o un fling hacia abajo) llama a
/// [onDismissIntent], que pasa por el guard.
class _GuardedDragHandle extends StatefulWidget {
  const _GuardedDragHandle({required this.onDismissIntent});

  final VoidCallback onDismissIntent;

  @override
  State<_GuardedDragHandle> createState() => _GuardedDragHandleState();
}

class _GuardedDragHandleState extends State<_GuardedDragHandle> {
  /// Descenso acumulado del arrastre en curso. Debe superar el alto de la
  /// propia barrita con holgura para leerse como intención de cierre y no
  /// como roce accidental.
  double _dragDy = 0;

  /// Umbral de desplazamiento (la mitad de la caja táctil del handle).
  static const double _dismissDragThreshold = 24.0;

  /// Umbral de fling — el mismo que usa Material para cerrar sus sheets.
  static const double _minFlingVelocity = 700.0;

  void _onDragStart(DragStartDetails details) => _dragDy = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDy += details.primaryDelta ?? 0;
  }

  void _onDragEnd(DragEndDetails details) {
    final flungDown = details.velocity.pixelsPerSecond.dy > _minFlingVelocity;
    if (flungDown || _dragDy > _dismissDragThreshold) {
      widget.onDismissIntent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handleColor =
        theme.bottomSheetTheme.dragHandleColor ??
        theme.colorScheme.onSurfaceVariant;
    final handleSize =
        theme.bottomSheetTheme.dragHandleSize ?? const Size(32, 4);

    return GestureDetector(
      key: appSheetDragHandleKey,
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Semantics(
        container: true,
        button: true,
        label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        onTap: widget.onDismissIntent,
        child: SizedBox(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: Center(
            child: Container(
              width: handleSize.width,
              height: handleSize.height,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(handleSize.height / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
