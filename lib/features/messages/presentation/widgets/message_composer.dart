import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../media/domain/failures/media_failure.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
import '../../../media/domain/repositories/media_repository.dart';
import '../bloc/messages_bloc.dart';

/// Caja de redacción del hilo: campo de texto multilínea + botón enviar. Vive al
/// fondo de la pantalla del hilo (fuera del scroll). Despacha
/// `MessagesSendRequested` con el texto recortado; el bloc pinta la burbuja
/// optimista. El botón se deshabilita cuando no hay texto. El adjuntar
/// multimedia es una rebanada posterior.
///
/// Stateful por el `TextEditingController`: escucha sus cambios para alternar el
/// estado del botón y se limpia tras un envío exitoso de intent (el resultado
/// del POST lo refleja la burbuja, no este campo).
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
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    context.read<MessagesBloc>().add(
      MessagesSendRequested(type: 'text', content: text),
    );
    _ctrl.clear();
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

  @override
  Widget build(BuildContext context) {
    final canSend = _ctrl.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp3,
        AppTokens.sp2,
        AppTokens.sp3,
        AppTokens.sp2 + context.safeBottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.surface1,
        border: Border(top: BorderSide(color: AppTokens.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
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
          Expanded(
            child: TextField(
              key: const Key('composer.input'),
              controller: _ctrl,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Mensaje',
                filled: true,
                fillColor: AppTokens.surface2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.sp4,
                  vertical: AppTokens.sp3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.sp2),
          IconButton(
            key: const Key('composer.send'),
            tooltip: 'Enviar',
            icon: const Icon(Icons.send),
            color: AppTokens.primary,
            onPressed: canSend ? _send : null,
          ),
        ],
      ),
    );
  }
}
