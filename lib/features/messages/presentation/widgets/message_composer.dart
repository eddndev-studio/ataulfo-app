import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../media/domain/failures/media_failure.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
import '../../../media/domain/repositories/media_repository.dart';
import '../../../quick_replies/presentation/bloc/quick_replies_bloc.dart';
import '../../../quick_replies/presentation/widgets/quick_replies_sheet.dart';
import '../bloc/messages_bloc.dart';

/// Caja de redacción del hilo: el [AppChatComposer] del kit con las acciones
/// propias de esta superficie (adjuntar imagen y respuestas rápidas ⚡) como
/// leading. Despacha `MessagesSendRequested` con el texto recortado; el bloc
/// pinta la burbuja optimista.
///
/// Stateful por el `TextEditingController` (compartido con el composer para
/// insertar respuestas rápidas y leer el caption del adjunto) y por el estado
/// de subida en vuelo.
class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key});

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _ctrl = TextEditingController();

  /// Subida de imagen en vuelo: deshabilita el adjuntar y muestra un spinner.
  bool _uploading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    context.read<MessagesBloc>().add(
      MessagesSendRequested(type: 'text', content: text),
    );
  }

  /// Adjunta una imagen: elige un archivo, lo sube (`/upload` → ref BARE) y
  /// despacha el envío `type:image` con el texto actual como caption. La burbuja
  /// optimista la pinta el bloc; un fallo de subida se avisa con un SnackBar
  /// (sin tocar el bloc, porque aún no hay envío). Captura bloc/picker/repo y el
  /// messenger ANTES del primer await.
  Future<void> _attach() async {
    final bloc = context.read<MessagesBloc>();
    final picker = context.read<MediaFilePicker>();
    final mediaRepo = context.read<MediaRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final picked = await picker.pick();
    if (picked == null) {
      return; // el usuario canceló
    }
    setState(() => _uploading = true);
    try {
      final uploaded = await mediaRepo.upload(
        bytes: picked.bytes,
        filename: picked.filename,
      );
      // El hilo pudo cerrarse o transitar a Loading/Failed durante la subida
      // (multi-segundo), desmontando el composer y disponiendo `_ctrl`. Sin esta
      // guarda, `_ctrl.clear()` tocaría un controller dispuesto. Espeja el guard
      // que ya tiene el `finally`.
      if (!mounted) {
        return;
      }
      bloc.add(
        MessagesSendRequested(
          type: 'image',
          content: _ctrl.text.trim(),
          mediaRef: uploaded.ref,
        ),
      );
      _ctrl.clear();
    } on MediaFailure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(_uploadError(f))));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  String _uploadError(MediaFailure f) => switch (f) {
    MediaTooLargeFailure() => 'La imagen es demasiado grande',
    MediaUnsupportedTypeFailure() => 'Tipo de archivo no soportado',
    MediaForbiddenFailure() => 'No tienes permiso para subir',
    MediaNetworkFailure() || MediaTimeoutFailure() => 'Sin conexión',
    _ => 'No se pudo subir la imagen',
  };

  /// Abre el selector ⚡ de respuestas rápidas e inserta la elegida. Lee el último
  /// estado del catálogo (cargado al abrir el hilo): si aún no cargó o no hay
  /// respuestas activas, avisa con un SnackBar en vez de abrir un sheet vacío.
  /// Captura el bloc/messenger ANTES del primer await.
  Future<void> _quickReply() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<QuickRepliesBloc>().state;
    if (state is! QuickRepliesLoaded) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cargando respuestas rápidas…')),
      );
      return;
    }
    final active = state.items.where((q) => !q.deleted).toList(growable: false);
    if (active.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay respuestas rápidas guardadas')),
      );
      return;
    }
    final message = await QuickRepliesSheet.open(context, active);
    if (!mounted || message == null) {
      return;
    }
    _insert(message);
  }

  /// Inserta texto en la posición del cursor, o al final si el campo nunca se
  /// enfocó. Un `TextEditingController` recién creado tiene
  /// `selection.offset == -1` (inválida); insertar por `replaceRange` con ese
  /// offset lanzaría `RangeError`, así que se distingue ese caso.
  void _insert(String text) {
    final current = _ctrl.text;
    final sel = _ctrl.selection;
    if (!sel.isValid) {
      final next = current + text;
      _ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      return;
    }
    final next = current.replaceRange(sel.start, sel.end, text);
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppChatComposer(
      controller: _ctrl,
      fieldKey: const Key('composer.input'),
      sendKey: const Key('composer.send'),
      onSend: _send,
      leading: <Widget>[
        IconButton(
          key: const Key('composer.attach'),
          tooltip: 'Adjuntar imagen',
          color: AppTokens.text2,
          onPressed: _uploading ? null : _attach,
          icon: _uploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
        ),
        IconButton(
          key: const Key('composer.quickreply'),
          tooltip: 'Respuestas rápidas',
          color: AppTokens.text2,
          onPressed: _quickReply,
          icon: const Icon(Icons.bolt),
        ),
      ],
    );
  }
}
