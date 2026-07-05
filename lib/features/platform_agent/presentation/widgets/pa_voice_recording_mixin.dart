import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/audio_recorder.dart';
import '../bloc/platform_agent_chat_bloc.dart';

/// Máquina de estados de la nota de voz del asistente, aislada del composer que
/// la hospeda. El host provee el bloc vía [voiceBloc] y llama [initVoice] /
/// [disposeVoice] desde su ciclo de vida; el resto (permiso, arranque, pausa,
/// envío, descarte) vive aquí. Toda transición avisa al bloc y refresca el host
/// con `setState`, de modo que la barra de grabación refleje el estado real.
mixin PaVoiceRecordingMixin<T extends StatefulWidget> on State<T> {
  /// Grabador compartido (Noop/ausente fuera de Android): NO se dispone aquí.
  /// null ⇒ la superficie no ofrece el micrófono.
  AudioRecorder? recorder;

  /// La plataforma puede grabar (Opus soportado). Falso ⇒ sin micrófono.
  bool canRecord = false;

  /// Grabando localmente: guía la limpieza en dispose (aborta el clip huérfano
  /// si el composer se destruye a media grabación, p. ej. al cambiar de tab).
  bool recording = false;

  /// Grabación pausada (manos libres): congela tiempo+waveform sin descartar.
  bool paused = false;

  /// Subiendo el clip tras detener: deshabilita enviar/pausar en la barra.
  bool sendingVoice = false;

  /// Bloc al que la máquina avisa cada transición. Lo provee el host (capturado
  /// al montar, así la limpieza en dispose no depende de un context ya inválido).
  PlatformAgentChatBloc get voiceBloc;

  /// Cablea el grabador desde el scope y consulta si la plataforma lo soporta.
  void initVoice() {
    recorder = _readRecorder(context);
    recorder?.isSupported().then((ok) {
      if (mounted) setState(() => canRecord = ok);
    });
  }

  /// Grabación viva al destruirse el composer (p. ej. cambio de tab): aborta el
  /// clip huérfano y revierte el estado del bloc para no volver a una barra de
  /// grabación sin grabador detrás.
  void disposeVoice() {
    if (recording) {
      unawaited(recorder?.cancel());
      if (!voiceBloc.isClosed) voiceBloc.add(const PaChatVoiceCancelled());
    }
  }

  /// Lee el grabador del scope de forma tolerante: superficies sin él cableado
  /// (tests, plataforma sin micrófono) simplemente no ofrecen la nota de voz.
  AudioRecorder? _readRecorder(BuildContext context) {
    try {
      return context.read<AudioRecorder>();
    } on Object {
      return null;
    }
  }

  /// Tap del micrófono: pide permiso y arranca la grabación en modo bloqueado
  /// (sin gesto de mantener). Sin permiso o ante un fallo del arranque, avisa y
  /// no entra a grabar.
  Future<void> startVoice() async {
    final rec = recorder;
    if (rec == null || recording) return;
    final messenger = ScaffoldMessenger.of(context);
    final granted = await rec.hasPermission();
    if (!mounted) return;
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Permite el micrófono para grabar notas de voz'),
        ),
      );
      return;
    }
    try {
      await rec.start();
    } on Object {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la grabación')),
        );
      }
      return;
    }
    if (!mounted) {
      unawaited(rec.cancel());
      return;
    }
    setState(() => recording = true);
    voiceBloc.add(const PaChatVoiceStarted());
  }

  /// Descarta la grabación en curso sin enviarla.
  Future<void> cancelVoice() async {
    await recorder?.cancel();
    if (!mounted) return;
    setState(() {
      recording = false;
      paused = false;
      sendingVoice = false;
    });
    voiceBloc.add(const PaChatVoiceCancelled());
  }

  /// Detiene la grabación y despacha el clip: el bloc corre el turno vía audio.
  /// Un clip vacío se descarta con aviso.
  Future<void> sendVoice() async {
    final rec = recorder;
    if (rec == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => sendingVoice = true);
    RecordedVoice? voice;
    try {
      voice = await rec.stop();
    } on Object {
      voice = null;
    }
    if (!mounted) return;
    if (voice == null || voice.bytes.isEmpty) {
      setState(() {
        recording = false;
        paused = false;
        sendingVoice = false;
      });
      voiceBloc.add(const PaChatVoiceCancelled());
      messenger.showSnackBar(
        const SnackBar(content: Text('No se grabó audio')),
      );
      return;
    }
    voiceBloc.add(PaChatVoiceSent(voice.bytes));
    if (mounted) {
      setState(() {
        recording = false;
        paused = false;
        sendingVoice = false;
      });
    }
  }

  /// Pausa/reanuda la grabación (manos libres). No aplica durante la subida.
  Future<void> togglePauseVoice() async {
    final rec = recorder;
    if (rec == null || sendingVoice) return;
    if (paused) {
      await rec.resume();
      if (mounted) setState(() => paused = false);
    } else {
      await rec.pause();
      if (mounted) setState(() => paused = true);
    }
  }
}
