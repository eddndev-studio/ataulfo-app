import 'package:flutter/material.dart';

import 'widgets/app_button.dart';

/// Punto único para pedir una confirmación sí/no en la app. Envuelve
/// [showDialog] con un [AlertDialog] cuyas acciones son [AppButton] del design
/// system: `text` para cancelar y `danger`/`filled` para confirmar según sea o
/// no una acción destructiva.
///
/// Devuelve `true` sólo si el operador confirma; cancelar, tocar fuera o el
/// botón físico atrás devuelven `false` (nunca null), de modo que el llamador
/// gatea la acción con un simple `if (await showAppConfirmDialog(...))`.
///
/// [confirmKey] y [cancelKey] viajan a sus botones para que las pruebas de
/// widget de cada pantalla los anclen sin depender del texto de los labels.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = true,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      void close(bool value) => Navigator.of(dialogContext).pop(value);
      final confirmButton = destructive
          ? AppButton.danger(
              key: confirmKey,
              label: confirmLabel,
              onPressed: () => close(true),
            )
          : AppButton.filled(
              key: confirmKey,
              label: confirmLabel,
              onPressed: () => close(true),
            );
      return AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: <Widget>[
          AppButton.text(
            key: cancelKey,
            label: cancelLabel,
            onPressed: () => close(false),
          ),
          confirmButton,
        ],
      );
    },
  );
  return confirmed ?? false;
}
