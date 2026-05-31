import 'dart:typed_data';

import 'package:ataulfo/features/media/data/repositories/caching_media_repository.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/domain/repositories/media_page_store.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInner extends Mock implements MediaRepository {}

/// Store en memoria que registra qué se persistió/leyó/limpió.
class _FakeStore implements MediaPageStore {
  final Map<String, MediaPage> _data = <String, MediaPage>{};
  final List<List<Object?>> writes = <List<Object?>>[];
  int clears = 0;
  bool throwOnWrite = false;

  String _k(String org, String? type) => '$org|${type ?? '_all'}';

  void seed(String org, String? type, MediaPage p) => _data[_k(org, type)] = p;

  @override
  Future<MediaPage?> read(String org, String? type) async =>
      _data[_k(org, type)];

  @override
  Future<void> write(String org, String? type, MediaPage p) async {
    if (throwOnWrite) throw Exception('disk full');
    writes.add(<Object?>[org, type, p]);
    _data[_k(org, type)] = p;
  }

  @override
  Future<void> clear() async {
    clears++;
    _data.clear();
  }
}

MediaAsset _asset(String ref) => MediaAsset(
  ref: ref,
  previewUrl: 'https://signed/$ref',
  filename: '$ref.png',
  contentType: 'image/png',
  size: 10,
  createdAt: DateTime.utc(2026, 1, 1),
);

MediaPage _page(List<String> refs, {String nextCursor = ''}) =>
    MediaPage(assets: refs.map(_asset).toList(), nextCursor: nextCursor);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  // Reloj inyectable: el TTL se mide contra esto, no contra el reloj real, para
  // que la expiración sea determinista en test.
  late DateTime fakeNow;
  DateTime now() => fakeNow;

  late _MockInner inner;

  setUp(() {
    fakeNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    inner = _MockInner();
  });

  CachingMediaRepository build({Duration ttl = const Duration(minutes: 3)}) =>
      CachingMediaRepository(inner, ttl: ttl, now: now);

  void stubList(MediaPage page) {
    when(
      () => inner.listAssets(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => page);
  }

  group('CachingMediaRepository — primera página', () {
    test(
      'memoiza por type: dos llamadas ⇒ el inner se pega una sola vez',
      () async {
        stubList(_page(<String>['media/a']));
        final repo = build();

        final p1 = await repo.listAssets(type: 'image');
        final p2 = await repo.listAssets(type: 'image');

        expect(p1, _page(<String>['media/a']));
        expect(p2, p1);
        verify(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'image',
          ),
        ).called(1);
      },
    );

    test('cursor != null NUNCA se cachea: siempre delega al inner', () async {
      stubList(_page(<String>['media/b'], nextCursor: 'c2'));
      final repo = build();

      await repo.listAssets(cursor: 'c1', type: 'image');
      await repo.listAssets(cursor: 'c1', type: 'image');

      verify(
        () => inner.listAssets(
          cursor: 'c1',
          limit: any(named: 'limit'),
          type: 'image',
        ),
      ).called(2);
    });

    test(
      'aislamiento por familia: image y video se cachean por separado',
      () async {
        when(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'image',
          ),
        ).thenAnswer((_) async => _page(<String>['media/img']));
        when(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'video',
          ),
        ).thenAnswer((_) async => _page(<String>['media/vid']));
        final repo = build();

        final img = await repo.listAssets(type: 'image');
        final vid = await repo.listAssets(type: 'video');
        final img2 = await repo.listAssets(type: 'image');

        expect(img.assets.single.ref, 'media/img');
        expect(vid.assets.single.ref, 'media/vid');
        expect(img2, img);
        verify(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'image',
          ),
        ).called(1);
        verify(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'video',
          ),
        ).called(1);
      },
    );
  });

  group('CachingMediaRepository — frescura', () {
    test(
      'invalidate() limpia: la siguiente primera página vuelve al inner',
      () async {
        stubList(_page(<String>['media/a']));
        final repo = build();

        await repo.listAssets(type: 'image'); // miss → inner (1)
        await repo.listAssets(type: 'image'); // hit
        repo.invalidate();
        await repo.listAssets(type: 'image'); // miss → inner (2)

        verify(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'image',
          ),
        ).called(2);
      },
    );

    test(
      'TTL: sirve cache dentro de la ventana, vuelve al inner al expirar',
      () async {
        stubList(_page(<String>['media/a']));
        final repo = build(ttl: const Duration(minutes: 3));

        await repo.listAssets(type: 'image'); // inner (1) @ 12:00
        fakeNow = fakeNow.add(const Duration(minutes: 2));
        await repo.listAssets(type: 'image'); // hit (2 min < 3)
        fakeNow = fakeNow.add(const Duration(minutes: 2)); // +4 min del fetch
        await repo.listAssets(type: 'image'); // miss → inner (2)

        verify(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'image',
          ),
        ).called(2);
      },
    );
  });

  group('CachingMediaRepository — mutaciones auto-invalidan', () {
    test(
      'upload delega al inner y limpia la primera página cacheada',
      () async {
        stubList(_page(<String>['media/a']));
        when(
          () => inner.upload(
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer(
          (_) async => const UploadedMedia(ref: 'media/c', previewUrl: null),
        );
        final repo = build();

        await repo.listAssets(type: 'image'); // inner list (1)
        await repo.upload(
          bytes: Uint8List.fromList(<int>[1]),
          filename: 'f.png',
        );
        await repo.listAssets(type: 'image'); // miss → inner list (2)

        verify(
          () => inner.upload(
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
          ),
        ).called(1);
        verify(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: 'image',
          ),
        ).called(2);
      },
    );

    test('subida fallida NO invalida (el catálogo no cambió)', () async {
      stubList(_page(<String>['media/a']));
      when(
        () => inner.upload(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).thenThrow(const MediaTooLargeFailure());
      final repo = build();

      await repo.listAssets(type: 'image'); // inner list (1)
      await expectLater(
        repo.upload(bytes: Uint8List.fromList(<int>[1]), filename: 'f.png'),
        throwsA(isA<MediaTooLargeFailure>()),
      );
      await repo.listAssets(type: 'image'); // sigue cacheado: sin inner extra

      verify(
        () => inner.listAssets(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: 'image',
        ),
      ).called(1);
    });
  });

  group('CachingMediaRepository — persistencia + offline (disco)', () {
    CachingMediaRepository withDisk(
      MediaPageStore store, {
      String? Function() orgId = _org1,
    }) => CachingMediaRepository(inner, now: now, store: store, orgId: orgId);

    test(
      'una lista online exitosa persiste la primera página por (org,type)',
      () async {
        final store = _FakeStore();
        stubList(_page(<String>['media/a']));
        await withDisk(store).listAssets(type: 'image');

        expect(store.writes, hasLength(1));
        expect(store.writes.first[0], 'org-1');
        expect(store.writes.first[1], 'image');
        expect(store.writes.first[2], _page(<String>['media/a']));
      },
    );

    test(
      'offline (el inner lanza) sirve la página persistida (stale)',
      () async {
        final store = _FakeStore()
          ..seed('org-1', 'image', _page(<String>['media/old']));
        when(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: any(named: 'type'),
          ),
        ).thenThrow(const MediaNetworkFailure());

        final page = await withDisk(store).listAssets(type: 'image');
        expect(page, _page(<String>['media/old']));
      },
    );

    test('offline + disco vacío ⇒ relanza el fallo', () async {
      final store = _FakeStore();
      when(
        () => inner.listAssets(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: any(named: 'type'),
        ),
      ).thenThrow(const MediaNetworkFailure());

      await expectLater(
        withDisk(store).listAssets(type: 'image'),
        throwsA(isA<MediaNetworkFailure>()),
      );
    });

    test(
      'la paginación profunda (cursor != null) jamás toca el disco',
      () async {
        final store = _FakeStore();
        stubList(_page(<String>['media/b']));
        await withDisk(store).listAssets(cursor: 'c1', type: 'image');
        expect(store.writes, isEmpty);
      },
    );

    test('invalidate purga también el disco', () async {
      final store = _FakeStore();
      withDisk(store).invalidate();
      expect(store.clears, 1);
    });

    test('sin orgId (no autenticado) no toca el disco', () async {
      final store = _FakeStore();
      stubList(_page(<String>['media/a']));
      final repo = withDisk(store, orgId: _noOrg);
      await repo.listAssets(type: 'image');
      expect(store.writes, isEmpty);

      when(
        () => inner.listAssets(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: any(named: 'type'),
        ),
      ).thenThrow(const MediaNetworkFailure());
      await expectLater(
        repo.listAssets(type: 'video'),
        throwsA(isA<MediaNetworkFailure>()),
      );
    });

    test(
      'un error que NO es MediaFailure se propaga (no sirve stale)',
      () async {
        // Un bug del datasource (TypeError, StateError…) NO debe enmascararse
        // sirviendo una página vieja: sólo un fallo de red cae al disco.
        final store = _FakeStore()
          ..seed('org-1', 'image', _page(<String>['media/old']));
        when(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: any(named: 'type'),
          ),
        ).thenThrow(StateError('bug del mapper'));

        await expectLater(
          withDisk(store).listAssets(type: 'image'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('la lista online se devuelve aunque el write a disco falle', () async {
      final store = _FakeStore()..throwOnWrite = true;
      stubList(_page(<String>['media/a']));
      final page = await withDisk(store).listAssets(type: 'image');
      expect(page, _page(<String>['media/a']));
    });

    test(
      'la página stale servida offline NO se memoiza: la siguiente reintenta la red',
      () async {
        final store = _FakeStore()
          ..seed('org-1', 'image', _page(<String>['media/old']));
        var calls = 0;
        when(
          () => inner.listAssets(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) throw const MediaNetworkFailure();
          return _page(<String>['media/fresh']);
        });
        final repo = withDisk(store);

        expect(
          await repo.listAssets(type: 'image'),
          _page(<String>['media/old']),
        );
        // La segunda entrada reintenta la red (no quedó memoizada la stale).
        expect(
          await repo.listAssets(type: 'image'),
          _page(<String>['media/fresh']),
        );
      },
    );
  });
}

String? _org1() => 'org-1';
String? _noOrg() => null;
