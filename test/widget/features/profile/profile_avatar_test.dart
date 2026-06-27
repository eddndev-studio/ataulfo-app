import 'dart:io';
import 'dart:typed_data';

import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/profile/data/cache/file_profile_photo_store.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG válido de 1×1 transparente: bytes decodificables para que el Image no
// dispare el errorBuilder y ensucie el log (la aserción mira el Image, no el
// pixel).
final _png1x1 = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

class _StubProfileRepo implements ProfileRepository {
  _StubProfileRepo(this._url);
  final String? _url;
  @override
  Future<ChatProfile> fetch(String botId, String chatLid) async => ChatProfile(
    chatLid: chatLid,
    isGroup: false,
    phone: null,
    displayName: null,
    photoUrl: _url,
    isArchived: false,
    isPinned: false,
    isMarkedUnread: false,
    mutedUntil: null,
  );
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('profile_avatar_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  FileProfilePhotoStore store() =>
      FileProfilePhotoStore(directoryProvider: () async => tmp);

  Future<void> pump(WidgetTester tester, ProfilePhotoCache cache) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(
            cache: cache,
            botId: 'bot-1',
            chatLid: '111@lid',
            name: 'Ada',
          ),
        ),
      ),
    );
  }

  testWidgets('con bytes en cache muestra la foto (Image), no la inicial', (
    tester,
  ) async {
    final cache = ProfilePhotoCache(
      profileRepo: _StubProfileRepo('https://cdn/p.jpg'),
      download: (_) async => _png1x1,
      store: store(),
    );

    // La caché resuelve con I/O de disco real (fuera del reloj fake del tester);
    // runAsync deja que ese future complete antes de repintar.
    await tester.runAsync(() async {
      await pump(tester, cache);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('sin foto (cache devuelve null) muestra la inicial', (
    tester,
  ) async {
    final cache = ProfilePhotoCache(
      profileRepo: _StubProfileRepo(null),
      download: (_) async => null,
      store: store(),
    );

    await pump(tester, cache);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });
}
