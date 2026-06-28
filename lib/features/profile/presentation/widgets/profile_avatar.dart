import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/design/widgets/app_avatar.dart';
import '../../data/cache/profile_photo_cache.dart';

/// [AppAvatar] que resuelve la foto del chat por la caché de fotos en disco
/// ([ProfilePhotoCache]). Mientras no haya bytes (cargando / sin foto) muestra
/// la inicial; cuando llegan, los pinta vía [MemoryImage] recortados al círculo.
///
/// Es un wrapper con estado sobre el avatar sin estado del kit: aísla el ciclo
/// de carga asíncrona (initState + reinicio al cambiar de chat) de la
/// presentación pura, que sigue siendo [AppAvatar].
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.cache,
    required this.botId,
    required this.chatLid,
    required this.name,
    this.size = 40,
  });

  final ProfilePhotoCache cache;
  final String botId;
  final String chatLid;

  /// Nombre visible: alimenta la inicial de fallback y el label accesible.
  final String name;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El widget se recicla al hacer scroll en la bandeja (mismo slot, otro
    // chat): si cambió el chat hay que olvidar la foto vieja y recargar, o se
    // pintaría la foto del contacto anterior un frame.
    if (oldWidget.botId != widget.botId ||
        oldWidget.chatLid != widget.chatLid) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    // Captura el chat al iniciar: si el slot se recicla a OTRO chat mientras la
    // carga está en vuelo, esta resolución no debe pintar la foto del chat
    // anterior sobre el nuevo (carrera de listas recicladas).
    final botId = widget.botId;
    final chatLid = widget.chatLid;
    final b = await widget.cache.photoFor(botId, chatLid);
    if (!mounted || botId != widget.botId || chatLid != widget.chatLid) return;
    setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return AppAvatar(
      name: widget.name,
      size: widget.size,
      imageProvider: b == null ? null : MemoryImage(b),
      // Clave estable del chat: el color del fallback no cambia con el nombre ni
      // difiere entre la bandeja y el hilo.
      colorKey: widget.chatLid,
    );
  }
}
