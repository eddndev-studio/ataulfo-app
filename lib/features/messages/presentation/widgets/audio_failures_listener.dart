import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/thread_audio_cubit.dart';

/// Anuncia con SnackBar cuando una nota de voz/audio no se pudo cargar o
/// reproducir (sin copia local ni firma viva, plataforma sin player). El cubit
/// señala la fuente fallida en `failedKey`; sólo el CAMBIO de ese campo dispara
/// el aviso. Compartido por los tres chats (clientes, entrenador y asistente).
class AudioFailuresListener extends StatelessWidget {
  const AudioFailuresListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ThreadAudioCubit, ThreadAudioState>(
      listenWhen: (prev, next) =>
          next.failedKey != null && prev.failedKey != next.failedKey,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reproducir el audio')),
      ),
      child: child,
    );
  }
}
