import 'dart:typed_data';

import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';

class _DummyProfileRepo implements ProfileRepository {
  @override
  Future<ChatProfile> fetch(String botId, String chatLid) =>
      throw UnimplementedError();
}

/// Caché de fotos no-op para tests de UI que no ejercitan la foto de perfil:
/// `photoFor` siempre resuelve a `null` (el avatar cae a la inicial) sin tocar
/// disco ni red. Evita que cada test de la bandeja tenga que cablear un repo,
/// un descargador y un store temporal solo para que el avatar pinte la inicial.
class NoopProfilePhotoCache extends ProfilePhotoCache {
  NoopProfilePhotoCache()
    : super(profileRepo: _DummyProfileRepo(), download: (_) async => null);

  @override
  Future<Uint8List?> photoFor(String botId, String chatLid) async => null;
}
