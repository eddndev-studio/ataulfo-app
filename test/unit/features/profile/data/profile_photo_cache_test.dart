import 'dart:io';
import 'dart:typed_data';

import 'package:ataulfo/features/profile/data/cache/file_profile_photo_store.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

ChatProfile _profile({String? photoUrl}) => ChatProfile(
  chatLid: 'c',
  isGroup: false,
  phone: '52155',
  displayName: 'Ada',
  photoUrl: photoUrl,
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);

void main() {
  late Directory tmp;
  late _MockProfileRepo repo;
  // El `now` inyectado se inicializa al reloj real y se avanza con Durations
  // reales: la frescura en disco compara `now()` contra el mtime (reloj real)
  // del archivo, así que un instante sintético lejano lo leería como rancio
  // (o futuro) y rompería las pruebas de TTL.
  late DateTime now;

  const botId = 'bot-1';
  const chatLid = '111@lid';
  final photo = Uint8List.fromList(<int>[10, 20, 30]);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('profile_cache_test');
    repo = _MockProfileRepo();
    now = DateTime.now();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  FileProfilePhotoStore makeStore() =>
      FileProfilePhotoStore(directoryProvider: () async => tmp);

  ProfilePhotoCache makeCache({
    required PhotoDownloader download,
    FileProfilePhotoStore? store,
    Duration ttl = const Duration(hours: 12),
    Duration failureTtl = const Duration(seconds: 30),
  }) => ProfilePhotoCache(
    profileRepo: repo,
    download: download,
    store: store ?? makeStore(),
    ttl: ttl,
    failureTtl: failureTtl,
    now: () => now,
  );

  test('(a) miss → fetch → descarga bytes → devuelve y cachea (L1 evita '
      'una segunda fetch)', () async {
    when(
      () => repo.fetch(botId, chatLid),
    ).thenAnswer((_) async => _profile(photoUrl: 'https://cdn/p.jpg'));
    final cache = makeCache(download: (_) async => photo);

    expect(await cache.photoFor(botId, chatLid), photo);
    expect(await cache.photoFor(botId, chatLid), photo);

    verify(() => repo.fetch(botId, chatLid)).called(1);
  });

  test('(b) photoUrl null → devuelve null y persiste marcador (sin refetch '
      'dentro del TTL)', () async {
    when(
      () => repo.fetch(botId, chatLid),
    ).thenAnswer((_) async => _profile(photoUrl: null));
    var downloads = 0;
    final cache = makeCache(
      download: (_) async {
        downloads++;
        return null;
      },
    );

    expect(await cache.photoFor(botId, chatLid), isNull);
    expect(await cache.photoFor(botId, chatLid), isNull);

    verify(() => repo.fetch(botId, chatLid)).called(1);
    expect(downloads, 0, reason: 'photoUrl null no dispara descarga');
  });

  test('(c) al expirar el TTL refetcha', () async {
    when(
      () => repo.fetch(botId, chatLid),
    ).thenAnswer((_) async => _profile(photoUrl: 'https://cdn/p.jpg'));
    final cache = makeCache(
      download: (_) async => photo,
      ttl: const Duration(hours: 12),
    );

    expect(await cache.photoFor(botId, chatLid), photo);
    now = now.add(const Duration(hours: 13));
    expect(await cache.photoFor(botId, chatLid), photo);

    verify(() => repo.fetch(botId, chatLid)).called(2);
  });

  test('(d) llamadas concurrentes deduplican (una sola fetch)', () async {
    when(() => repo.fetch(botId, chatLid)).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _profile(photoUrl: 'https://cdn/p.jpg');
    });
    final cache = makeCache(download: (_) async => photo);

    final results = await Future.wait([
      cache.photoFor(botId, chatLid),
      cache.photoFor(botId, chatLid),
    ]);

    expect(results, [photo, photo]);
    verify(() => repo.fetch(botId, chatLid)).called(1);
  });

  test(
    '(e) fetch lanza → sirve disco rancio si lo hay y NO persiste',
    () async {
      final store = makeStore();
      // Siembra disco con bytes y déjalos rancios avanzando el reloj.
      await store.write('$botId $chatLid', photo);
      now = now.add(const Duration(hours: 13));
      when(() => repo.fetch(botId, chatLid)).thenThrow(Exception('boom'));
      final cache = makeCache(download: (_) async => photo, store: store);

      expect(await cache.photoFor(botId, chatLid), photo);

      // No se persistió un marcador nuevo: el disco conserva los bytes rancios.
      final disk = await store.read('$botId $chatLid');
      expect(disk!.bytes, photo);
    },
  );

  test('(e bis) fetch lanza y no hay disco → null', () async {
    when(() => repo.fetch(botId, chatLid)).thenThrow(Exception('boom'));
    final cache = makeCache(download: (_) async => photo);

    expect(await cache.photoFor(botId, chatLid), isNull);
  });

  test(
    '(f) descarga vacía (200 sin cuerpo) NO se cachea como "sin foto"',
    () async {
      when(
        () => repo.fetch(botId, chatLid),
      ).thenAnswer((_) async => _profile(photoUrl: 'https://cdn/p.jpg'));
      final store = makeStore();
      final cache = makeCache(
        download: (_) async => Uint8List(0),
        store: store,
      );

      expect(await cache.photoFor(botId, chatLid), isNull);
      // No se persistió un marcador de "sin foto" (archivo de 0 bytes): un cuerpo
      // vacío es un fallo, no la ausencia de foto.
      expect(await store.read('$botId $chatLid'), isNull);
    },
  );

  test('(g) caché de fallos: no re-resuelve dentro de failureTtl', () async {
    when(
      () => repo.fetch(botId, chatLid),
    ).thenAnswer((_) async => _profile(photoUrl: 'https://cdn/p.jpg'));
    final cache = makeCache(download: (_) async => null); // descarga falla

    expect(await cache.photoFor(botId, chatLid), isNull);
    expect(await cache.photoFor(botId, chatLid), isNull);

    verify(() => repo.fetch(botId, chatLid)).called(1); // no martilleó
  });

  test('(h) tras failureTtl re-resuelve', () async {
    when(
      () => repo.fetch(botId, chatLid),
    ).thenAnswer((_) async => _profile(photoUrl: 'https://cdn/p.jpg'));
    final cache = makeCache(
      download: (_) async => null,
      failureTtl: const Duration(seconds: 30),
    );

    expect(await cache.photoFor(botId, chatLid), isNull);
    now = now.add(const Duration(seconds: 31));
    expect(await cache.photoFor(botId, chatLid), isNull);

    verify(() => repo.fetch(botId, chatLid)).called(2);
  });

  test('invalidate limpia L1 y disco', () async {
    final store = makeStore();
    when(
      () => repo.fetch(botId, chatLid),
    ).thenAnswer((_) async => _profile(photoUrl: 'https://cdn/p.jpg'));
    final cache = makeCache(download: (_) async => photo, store: store);

    expect(await cache.photoFor(botId, chatLid), photo);
    await cache.invalidate();

    expect(await store.read('$botId $chatLid'), isNull);
    // Tras invalidar, una nueva consulta vuelve a pegarle al repo.
    expect(await cache.photoFor(botId, chatLid), photo);
    verify(() => repo.fetch(botId, chatLid)).called(2);
  });
}
