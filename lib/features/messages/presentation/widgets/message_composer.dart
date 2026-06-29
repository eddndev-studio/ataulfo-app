import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_chat_composer.dart';
import '../../../media/domain/failures/media_failure.dart';
import '../../../media/domain/repositories/media_file_picker.dart';
import '../../../media/domain/repositories/media_repository.dart';
import '../../../quick_replies/presentation/bloc/quick_replies_bloc.dart';
import '../../../quick_replies/presentation/widgets/quick_replies_sheet.dart';
import '../../domain/repositories/audio_recorder.dart';
import '../bloc/messages_bloc.dart';
import 'voice_recording_bar.dart';

/// Caja de redacción del hilo: el [AppChatComposer] del kit con las acciones
/// propias de esta superficie (adjuntar imagen, respuestas rápidas ⚡ y grabar
/// nota de voz 🎤) como leading. Despacha `MessagesSendRequested` con el texto
/// recortado; el bloc pinta la burbuja optimista.
///
/// Stateful por el `TextEditingController` (compartido con el composer para
/// insertar respuestas rápidas y leer el caption del adjunto), por el estado
/// de subida en vuelo y por la grabación de voz: mientras graba, la barra de
/// grabación reemplaza al composer.
class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key});

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _ctrl = TextEditingController();

  /// Subida de imagen en vuelo: deshabilita el adjuntar y muestra un spinner.
  bool _uploading = false;

  /// Grabador de voz (singleton de la app; Noop fuera de Android). El composer
  /// NO lo dispone: lo comparte toda la app.
  late final AudioRecorder _recorder;

  /// Si la plataforma puede grabar (Android API>=29). Falso ⇒ sin botón 🎤.
  bool _canRecord = false;

  /// Arrancando la grabación (entre el toque y que `start()` resuelve):
  /// deshabilita el botón y bloquea la re-entrada por doble toque, que de otro
  /// modo lanzaría dos grabaciones concurrentes (el grabador es compartido).
  bool _starting = false;

  /// Grabando: la barra de grabación reemplaza al composer.
  bool _recording = false;

  /// Nota de voz subiéndose tras detener: deshabilita enviar/cancelar.
  bool _sendingVoice = false;

  /// Duración mínima de una nota de voz: por debajo se descarta (toque
  /// accidental) en vez de enviar un clip vacío.
  static const Duration _minVoiceDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _recorder = context.read<AudioRecorder>();
    _recorder.isSupported().then((ok) {
      if (mounted) setState(() => _canRecord = ok);
    });
  }

  @override
  void dispose() {
    // Si el hilo se cierra mientras graba, aborta la grabación huérfana (el
    // recorder es compartido, no se dispone aquí).
    if (_recording) unawaited(_recorder.cancel());
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

  /// Inicia la grabación: pide permiso de micrófono y arranca el grabador. Sin
  /// permiso avisa con un SnackBar; un fallo del arranque (encoder no soportado
  /// pese al gate) degrada con aviso en vez de tumbar la UI. Captura el
  /// messenger ANTES del await.
  Future<void> _startRecording() async {
    // Bloquea la re-entrada por doble toque ANTES del primer await: sin esto,
    // dos toques rápidos lanzan dos start() concurrentes sobre el grabador
    // compartido (timer/suscripción huérfanos).
    if (_starting || _recording) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    // `started` distingue el éxito de cualquier salida (permiso denegado, o un
    // throw de hasPermission()/start() en el canal de plataforma): así
    // `_starting` SIEMPRE se resetea si no entramos a grabar, sin dejar el
    // botón deshabilitado para siempre.
    var started = false;
    try {
      final granted = await _recorder.hasPermission();
      if (!mounted) return;
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Permite el micrófono para grabar notas de voz'),
          ),
        );
      } else {
        await _recorder.start();
        started = true;
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la grabación')),
        );
      }
    }
    if (!mounted) {
      // Se desmontó durante el await: aborta la grabación huérfana.
      if (started) unawaited(_recorder.cancel());
      return;
    }
    if (started) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _starting = false;
        _recording = true;
      });
    } else {
      setState(() => _starting = false);
    }
  }

  /// Descarta la grabación en curso y vuelve al composer.
  Future<void> _cancelRecording() async {
    unawaited(HapticFeedback.selectionClick());
    await _recorder.cancel();
    if (mounted) setState(() => _recording = false);
  }

  /// Detiene la grabación, sube el clip Opus (`/upload` → ref BARE) y despacha
  /// `type:ptt`. Una grabación vacía (muy corta / fallo) se descarta con aviso;
  /// un fallo de subida se avisa con un SnackBar. Captura bloc/repo/messenger
  /// ANTES del primer await.
  Future<void> _stopAndSend() async {
    final bloc = context.read<MessagesBloc>();
    final mediaRepo = context.read<MediaRepository>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sendingVoice = true);
    RecordedVoice? voice;
    try {
      voice = await _recorder.stop();
    } catch (_) {
      voice = null;
    }
    if (!mounted) return;
    if (voice == null || voice.bytes.isEmpty) {
      setState(() {
        _recording = false;
        _sendingVoice = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('No se grabó audio')),
      );
      return;
    }
    if (voice.duration < _minVoiceDuration) {
      setState(() {
        _recording = false;
        _sendingVoice = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Nota de voz muy corta')),
      );
      return;
    }
    try {
      final uploaded = await mediaRepo.upload(
        bytes: voice.bytes,
        filename: 'voice.ogg',
      );
      if (!mounted) return;
      bloc.add(
        MessagesSendRequested(
          type: 'ptt',
          content: '',
          mediaRef: uploaded.ref,
          waveform: voice.waveform.isEmpty ? null : voice.waveform,
        ),
      );
    } on MediaFailure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(_voiceUploadError(f))));
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _sendingVoice = false;
        });
      }
    }
  }

  String _voiceUploadError(MediaFailure f) => switch (f) {
    MediaForbiddenFailure() => 'No tienes permiso para enviar',
    MediaNetworkFailure() || MediaTimeoutFailure() => 'Sin conexión',
    _ => 'No se pudo enviar la nota de voz',
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
    if (_recording) {
      return VoiceRecordingBar(
        elapsed: _recorder.elapsed,
        amplitude: _recorder.amplitude,
        onCancel: _cancelRecording,
        onSend: _stopAndSend,
        sending: _sendingVoice,
      );
    }
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
        if (_canRecord)
          IconButton(
            key: const Key('composer.mic'),
            tooltip: 'Grabar nota de voz',
            color: AppTokens.text2,
            onPressed: _starting ? null : _startRecording,
            icon: const Icon(Icons.mic_none_outlined),
          ),
      ],
    );
  }
}
