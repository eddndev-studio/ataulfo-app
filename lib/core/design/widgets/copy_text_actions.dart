import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_bottom_sheet.dart';
import '../tokens.dart';

/// Acciones de copiar/seleccionar el texto de una burbuja de chat, compartidas
/// por todas las superficies de mensajería (hilo de WhatsApp, entrenador,
/// asistente) para que copiar se vea y se comporte igual en todas.

/// Copia [text] al portapapeles y avisa con un SnackBar.
Future<void> copyTextToClipboard(
  BuildContext context,
  String text, {
  String confirm = 'Mensaje copiado',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  // Copias seguidas reemplazan el aviso: encolado, el segundo esperaría los
  // segundos del primero y la acción se sentiría sin respuesta.
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(confirm)));
}

/// Hoja inferior con [text] en un `SelectableText`, para copiar un fragmento
/// (un RFC, un número de pedido) en vez del texto completo.
Future<void> showSelectableTextSheet(BuildContext context, String text) {
  final textTheme = Theme.of(context).textTheme;
  return showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp4,
          vertical: AppTokens.sp5,
        ),
        child: SelectableText(
          text,
          key: const Key('copy.select_sheet.text'),
          style: textTheme.bodyLarge,
        ),
      ),
    ),
  );
}

/// Hoja de acciones de texto (long-press de una burbuja): "Copiar" (al
/// portapapeles + aviso) y "Seleccionar texto" (abre [showSelectableTextSheet]).
/// [keyId] parametriza las keys de prueba por superficie/mensaje.
Future<void> showCopyTextActions(
  BuildContext context,
  String text, {
  required String keyId,
  String copyConfirm = 'Mensaje copiado',
}) {
  // El navigator raíz se captura ANTES de abrir la hoja: las acciones lo usan
  // para copiar / abrir la hoja de selección una vez cerrada esta, sin tocar un
  // BuildContext que cruzó un await.
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  return showAppBottomSheet<void>(
    context,
    backgroundColor: AppTokens.surface1,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            key: Key('copy.$keyId.copy'),
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copiar'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              copyTextToClipboard(
                rootNavigator.context,
                text,
                confirm: copyConfirm,
              );
            },
          ),
          ListTile(
            key: Key('copy.$keyId.select'),
            leading: const Icon(Icons.text_fields_outlined),
            title: const Text('Seleccionar texto'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showSelectableTextSheet(rootNavigator.context, text);
            },
          ),
        ],
      ),
    ),
  );
}

/// Envuelve una burbuja de chat para que un long-press ofrezca copiar/
/// seleccionar su [text]. Si [text] está vacío/whitespace no engancha el gesto
/// (no hay nada que copiar — p. ej. una burbuja sólo-adjunto).
class CopyableBubble extends StatelessWidget {
  const CopyableBubble({
    required this.text,
    required this.keyId,
    required this.child,
    super.key,
  });

  final String text;

  /// Identificador para las keys de prueba de la hoja (`copy.<keyId>.copy`).
  final String keyId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return child;
    return GestureDetector(
      onLongPress: () => showCopyTextActions(context, text, keyId: keyId),
      child: child,
    );
  }
}
