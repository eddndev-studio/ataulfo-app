import 'package:flutter/material.dart';

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
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}
