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
import '../../data/cache/message_media_cache.dart';
import '../../domain/repositories/audio_recorder.dart';
import '../bloc/messages_bloc.dart';
import 'voice_recording_bar.dart';

/// Acción decidida al soltar el micrófono (o al cancelarse el puntero), por si el
/// dedo se levanta ANTES de que `start()` resuelva: se guarda y se aplica en
/// cuanto la grabación está lista.
enum _Release { send, discard, cancel }

/// Caja de redacción del hilo: el [AppChatComposer] del kit con las acciones
/// propias de esta superficie (adjuntar imagen y respuestas rápidas ⚡ como
/// leading; grabar nota de voz 🎤 en el slot final mientras el campo está vacío).
/// Despacha `MessagesSendRequested` con el texto recortado; el bloc pinta la
/// burbuja optimista.
///
/// La nota de voz sigue el gesto de WhatsApp: MANTENER el micrófono graba;
/// deslizar ARRIBA bloquea (manos libres, con botones); deslizar a la IZQUIERDA
/// descarta; un toque corto no graba (muestra una pista). Un solo `Listener`
/// estable envuelve todo el footer y enruta el puntero —así nada se reparenta ni
/// se desmonta a media pulsación—; el micrófono sólo se LOCALIZA por su
/// `GlobalKey` al tocar.
///
/// Excede el tope de 400 LOC del repo a propósito: concentra todo el estado del
/// composer del hilo (texto + adjunto + ⚡ + máquina de gesto de voz) en un solo
/// dueño; partirlo obligaría a cablear el ciclo de grabación a través de un
/// controlador externo sin ganancia real de claridad.
class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key, this.now});

  /// Reloj para medir cuánto se mantuvo el dedo (toque corto vs mantener).
  /// Inyectable en tests; en producción es `DateTime.now`.
  final DateTime Function()? now;

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

  /// Arrancando la grabación (entre tocar y que `start()` resuelve): bloquea la
  /// re-entrada por doble toque, que de otro modo lanzaría dos grabaciones
  /// concurrentes sobre el grabador compartido.
  bool _starting = false;

  /// Grabando: la barra de grabación reemplaza al composer.
  bool _recording = false;

  /// Bloqueada (manos libres): se deslizó arriba; soltar el dedo NO envía, y
  /// aparecen los botones de enviar/descartar de la [VoiceRecordingBar].
  bool _locked = false;

  /// El dedo cruzó el umbral de cancelar (deslizó a la izquierda): soltar
  /// descarta. Mientras esté armado, la barra lo señala en rojo.
  bool _cancelArmed = false;

  /// Avance hacia el bloqueo (0..1): ilumina el candado en la barra de mantener.
  double _lockProgress = 0;

  /// Nota de voz subiéndose tras detener: deshabilita enviar/cancelar.
  bool _sendingVoice = false;

  // Estado del gesto del micrófono.
  final GlobalKey _micKey = GlobalKey();
  int? _activePointer;
  Offset _downPos = Offset.zero;
  DateTime _heldFrom = DateTime.fromMillisecondsSinceEpoch(0);

  /// Acción pendiente si el dedo se soltó antes de que `start()` resolviera.
  _Release? _pending;

  /// Duración mínima de una nota: un toque más corto no graba (se descarta y se
  /// muestra una pista en vez de subir un clip vacío).
  static const Duration _minVoiceDuration = Duration(milliseconds: 700);

  /// Píxeles que hay que deslizar ARRIBA para bloquear / IZQUIERDA para cancelar.
  static const double _lockThreshold = 80;
  static const double _cancelThreshold = 100;

  DateTime Function() get _now => widget.now ?? DateTime.now;

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
    if (_recording || _starting) unawaited(_recorder.cancel());
    _ctrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    context.read<MessagesBloc>().add(
      MessagesSendRequested(type: 'text', content: text),
    );
  }

  // ── Gesto del micrófono ───────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (!_canRecord || _recording || _starting) return;
    final box = _micKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(e.position);
    final hitMic =
        local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
    if (!hitMic) return; // toque en otro control: que lo maneje normalmente
    _activePointer = e.pointer;
    _downPos = e.position;
    _heldFrom = _now();
    _pending = null;
    _locked = false;
    _cancelArmed = false;
    _lockProgress = 0;
    unawaited(_startRecording());
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer || _locked || !_recording) return;
    final dy = e.position.dy - _downPos.dy; // < 0 = arriba
    final dx = e.position.dx - _downPos.dx; // < 0 = izquierda
    if (-dy >= _lockThreshold) {
      _lock();
      return;
    }
    final progress = (-dy / _lockThreshold).clamp(0.0, 1.0);
    final armed = dx <= -_cancelThreshold;
    if (progress != _lockProgress || armed != _cancelArmed) {
      setState(() {
        _lockProgress = progress;
        _cancelArmed = armed;
      });
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_locked) return; // manos libres: soltar no envía
    final held = _now().difference(_heldFrom);
    final action = _cancelArmed
        ? _Release.cancel
        : (held < _minVoiceDuration ? _Release.discard : _Release.send);
    _applyRelease(action);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_locked) return;
    _applyRelease(_Release.cancel);
  }

  /// Aplica la acción del release; si aún se está arrancando, la deja pendiente
  /// para cuando `start()` resuelva (carrera soltar-antes-de-grabar).
  void _applyRelease(_Release action) {
    if (_recording) {
      _runRelease(action);
    } else if (_starting) {
      _pending = action;
    }
    // Ni grabando ni arrancando (permiso denegado / fallo): nada que hacer.
  }

  void _runRelease(_Release action) {
    switch (action) {
      case _Release.send:
        unawaited(_stopAndSend());
      case _Release.discard:
        unawaited(_discardQuickTap());
      case _Release.cancel:
        unawaited(_cancelRecording());
    }
  }

  void _lock() {
    if (!_recording || _locked) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _locked = true;
      _cancelArmed = false;
      _lockProgress = 1.0;
    });
  }

  /// Inicia la grabación: pide permiso de micrófono y arranca el grabador. Sin
  /// permiso avisa con un SnackBar; un fallo del arranque (encoder no soportado
  /// pese al gate) degrada con aviso. Si el dedo ya se soltó (carrera), aplica la
  /// acción pendiente en cuanto la grabación queda lista.
  Future<void> _startRecording() async {
    if (_starting || _recording) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
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
      if (started) unawaited(_recorder.cancel());
      return;
    }
    if (started) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _starting = false;
        _recording = true;
      });
      final pending = _pending;
      _pending = null;
      if (pending != null) _runRelease(pending);
    } else {
      setState(() => _starting = false);
      _pending = null;
    }
  }

  /// Toque corto (no se mantuvo): descarta la grabación y muestra la pista de
  /// "mantén para grabar". NUNCA sube — un toque accidental no es una nota.
  Future<void> _discardQuickTap() async {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.selectionClick());
    await _recorder.cancel();
    if (!mounted) return;
    _resetGesture();
    messenger.showSnackBar(
      const SnackBar(content: Text('Mantén para grabar una nota de voz')),
    );
  }

  /// Descarta la grabación en curso (deslizó a cancelar / puntero cancelado).
  Future<void> _cancelRecording() async {
    unawaited(HapticFeedback.selectionClick());
    await _recorder.cancel();
    if (mounted) _resetGesture();
  }

  void _resetGesture() => setState(() {
    _recording = false;
    _locked = false;
    _cancelArmed = false;
    _lockProgress = 0;
  });

  /// Adjunta una imagen: elige un archivo, lo sube (`/upload` → ref BARE) y
  /// despacha el envío `type:image` con el texto actual como caption. La burbuja
  /// optimista la pinta el bloc; un fallo de subida se avisa con un SnackBar.
  /// Captura bloc/picker/repo y el messenger ANTES del primer await.
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

  /// Detiene la grabación, sube el clip Opus (`/upload` → ref BARE) y despacha
  /// `type:ptt`. Una grabación vacía o muy corta se descarta con aviso; un fallo
  /// de subida se avisa con un SnackBar. Captura bloc/repo/cache/messenger ANTES
  /// del primer await.
  Future<void> _stopAndSend() async {
    final bloc = context.read<MessagesBloc>();
    final mediaRepo = context.read<MediaRepository>();
    final mediaCache = context.read<MessageMediaCache>();
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
      _resetGesture();
      setState(() => _sendingVoice = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('No se grabó audio')),
      );
      return;
    }
    if (voice.duration < _minVoiceDuration) {
      _resetGesture();
      setState(() => _sendingVoice = false);
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
      // Siembra la caché con los bytes grabados bajo el ref definitivo: la
      // burbuja reconciliada reproduce desde disco al instante (sin esperar la
      // URL firmada) y la duración aparece de una.
      await mediaCache.cache(uploaded.ref, voice.bytes);
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
        _resetGesture();
        setState(() => _sendingVoice = false);
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

  /// El micrófono. Un único `Listener` exterior enruta el puntero; este botón es
  /// sólo visual + objetivo de hit-test (vía [_micKey]) y semántica. Resaltado
  /// (círculo primary) mientras se graba.
  ///
  /// El gesto de mantener no es operable por lector de pantalla (explore-by-touch
  /// se come la pulsación), así que expone una ACCIÓN semántica `onTap` que
  /// arranca la grabación en modo BLOQUEADO: la [VoiceRecordingBar] resultante
  /// trae botones accesibles de enviar/descartar. Sin esto, AT no podría grabar.
  Widget _micButton({required bool active}) => KeyedSubtree(
    key: _micKey,
    child: Semantics(
      button: true,
      label: 'Grabar nota de voz',
      onTap: active ? null : _startLockedForA11y,
      child: Container(
        key: const Key('composer.mic'),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active ? AppTokens.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic_none_outlined,
          color: active ? AppTokens.onPrimary : AppTokens.text2,
        ),
      ),
    ),
  );

  /// Ruta accesible (acción semántica `onTap`): arranca la grabación y la deja
  /// BLOQUEADA, para que el lector de pantalla llegue a los botones de
  /// enviar/descartar de la [VoiceRecordingBar] sin depender del gesto de
  /// mantener.
  Future<void> _startLockedForA11y() async {
    if (_starting || _recording) return;
    await _startRecording();
    if (mounted && _recording) setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    // Un solo Listener estable envuelve TODO el footer (composer / barra de
    // mantener / barra bloqueada): nunca se reparenta ni se desmonta, así el
    // puntero del gesto se entrega sin interrupción hasta soltar. Es pasivo
    // (no reclama la arena), así que los toques del campo y los botones siguen
    // funcionando.
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_recording && _locked) {
      return VoiceRecordingBar(
        elapsed: _recorder.elapsed,
        amplitude: _recorder.amplitude,
        onCancel: _cancelRecording,
        onSend: _stopAndSend,
        sending: _sendingVoice,
      );
    }
    if (_recording) {
      return VoiceHoldBar(
        elapsed: _recorder.elapsed,
        cancelArmed: _cancelArmed,
        lockProgress: _lockProgress,
        sending: _sendingVoice,
        trailing: _micButton(active: true),
      );
    }
    return AppChatComposer(
      controller: _ctrl,
      fieldKey: const Key('composer.input'),
      sendKey: const Key('composer.send'),
      onSend: _send,
      emptyTrailing: _canRecord ? _micButton(active: false) : null,
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
