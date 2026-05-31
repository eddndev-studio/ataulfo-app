import 'dart:async';
import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_gallery_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MediaRepository {}

class _MockPicker extends Mock implements MediaFilePicker {}

MediaAsset _asset(String ref) => MediaAsset(
  ref: ref,
  previewUrl: 'https://signed/$ref',
  filename: '$ref.png',
  contentType: 'image/png',
  size: 10,
  createdAt: DateTime.utc(2026, 1, 1),
);

final _a = _asset('media/a');
final _b = _asset('media/b');
final _c = _asset('media/c');
final _d = _asset('media/d');

final _picked = PickedMedia(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  filename: 'new.png',
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  MediaGalleryBloc build(_MockRepo repo, _MockPicker picker) =>
      MediaGalleryBloc(repo: repo, picker: picker);

  group('MediaGalleryBloc', () {
    test('estado inicial = MediaGalleryInitial', () {
      expect(
        build(_MockRepo(), _MockPicker()).state,
        const MediaGalleryInitial(),
      );
    });

    group('filtro por type (galería como picker)', () {
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'construido con type ⇒ propaga ?type= en la primera página',
        build: () {
          _lastRepo = _MockRepo();
          when(
            () => _lastRepo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
              type: any(named: 'type'),
            ),
          ).thenAnswer(
            (_) async => MediaPage(assets: <MediaAsset>[_a], nextCursor: ''),
          );
          return MediaGalleryBloc(
            repo: _lastRepo,
            picker: _MockPicker(),
            type: 'video',
          );
        },
        act: (b) => b.add(const MediaGalleryLoadRequested()),
        verify: (b) {
          verify(
            () => _lastRepo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
              type: 'video',
            ),
          ).called(1);
        },
      );
    });

    group('MediaGalleryLoadRequested (primera página)', () {
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'ok → [Loading, Loaded(items, nextCursor)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                MediaPage(assets: <MediaAsset>[_a, _b], nextCursor: 'cur-1'),
          );
          return build(repo, _MockPicker());
        },
        act: (b) => b.add(const MediaGalleryLoadRequested()),
        expect: () => <MediaGalleryState>[
          const MediaGalleryLoading(),
          MediaGalleryLoaded(items: <MediaAsset>[_a, _b], nextCursor: 'cur-1'),
        ],
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'ok vacío → [Loading, Loaded([], "")] con hasMore=false',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                const MediaPage(assets: <MediaAsset>[], nextCursor: ''),
          );
          return build(repo, _MockPicker());
        },
        act: (b) => b.add(const MediaGalleryLoadRequested()),
        expect: () => <MediaGalleryState>[
          const MediaGalleryLoading(),
          const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
        ],
        verify: (b) {
          final s = b.state as MediaGalleryLoaded;
          expect(s.hasMore, isFalse);
        },
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'forbidden → [Loading, Failed(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const MediaForbiddenFailure());
          return build(repo, _MockPicker());
        },
        act: (b) => b.add(const MediaGalleryLoadRequested()),
        expect: () => <MediaGalleryState>[
          const MediaGalleryLoading(),
          const MediaGalleryFailed(MediaForbiddenFailure()),
        ],
      );
    });

    group('MediaGalleryLoadMoreRequested (guardas de paginación)', () {
      // GUARDA (a): append SIN duplicar — la página nueva se concatena.
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'append: items finales == viejos + nuevos (cuenta y orden, sin duplicados)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: 'cur-1',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                MediaPage(assets: <MediaAsset>[_c, _d], nextCursor: 'cur-2'),
          );
          return build(repo, _MockPicker());
        },
        seed: () => MediaGalleryLoaded(
          items: <MediaAsset>[_a, _b],
          nextCursor: 'cur-1',
        ),
        act: (b) => b.add(const MediaGalleryLoadMoreRequested()),
        expect: () => <MediaGalleryState>[
          MediaGalleryLoaded(
            items: <MediaAsset>[_a, _b],
            nextCursor: 'cur-1',
            isLoadingMore: true,
          ),
          MediaGalleryLoaded(
            items: <MediaAsset>[_a, _b, _c, _d],
            nextCursor: 'cur-2',
          ),
        ],
        verify: (b) {
          final s = b.state as MediaGalleryLoaded;
          expect(s.items, <MediaAsset>[_a, _b, _c, _d]);
          final refs = s.items.map((a) => a.ref).toList();
          expect(refs.toSet().length, refs.length); // sin duplicados
        },
      );

      // GUARDA (b): hasMore=false (next_cursor vacío) ⇒ LoadMore es no-op.
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'cursor vacío ⇒ LoadMore no emite y NO llama al repo',
        build: () {
          _lastRepo = _MockRepo();
          return build(_lastRepo, _MockPicker());
        },
        seed: () => MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: ''),
        act: (b) => b.add(const MediaGalleryLoadMoreRequested()),
        expect: () => <MediaGalleryState>[],
        verify: (_) {
          verifyNever(
            () => _lastRepo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      // GUARDA (c): load-more concurrente guardado — si ya hay una en vuelo,
      // un segundo LoadMore NO dispara un 2º fetch. La primera petición se
      // retiene viva con un Completer para que el segundo evento llegue a su
      // guarda con `isLoadingMore == true` todavía (un mock que resuelve al
      // instante terminaría la 1ª antes de que el 2º evento atraviese el
      // pipeline, y no habría solape que guardar).
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'dos LoadMore concurrentes ⇒ una sola llamada al repo (guarda de concurrencia)',
        build: () {
          _lastRepo = _MockRepo();
          _gate = Completer<MediaPage>();
          when(
            () => _lastRepo.listAssets(
              cursor: 'cur-1',
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => _gate.future);
          return build(_lastRepo, _MockPicker());
        },
        seed: () =>
            MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: 'cur-1'),
        act: (b) async {
          b
            ..add(const MediaGalleryLoadMoreRequested())
            ..add(const MediaGalleryLoadMoreRequested());
          // Drena la cola de microtasks: ambos eventos alcanzan su guarda con
          // la 1ª petición aún colgada del Completer.
          await Future<void>.delayed(Duration.zero);
          _gate.complete(
            MediaPage(assets: <MediaAsset>[_c], nextCursor: 'cur-2'),
          );
        },
        verify: (_) {
          verify(
            () => _lastRepo.listAssets(
              cursor: 'cur-1',
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'load-more con error → mantiene items y cursor visibles (no Failed)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: 'cur-1',
              limit: any(named: 'limit'),
            ),
          ).thenThrow(const MediaNetworkFailure());
          return build(repo, _MockPicker());
        },
        seed: () =>
            MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: 'cur-1'),
        act: (b) => b.add(const MediaGalleryLoadMoreRequested()),
        verify: (b) {
          expect(b.state, isA<MediaGalleryLoaded>());
          final s = b.state as MediaGalleryLoaded;
          expect(s.items, <MediaAsset>[_a]);
          expect(s.nextCursor, 'cur-1');
          expect(s.isLoadingMore, isFalse);
        },
      );
    });

    group('MediaGalleryRefreshRequested', () {
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'desde Loaded → recarga primera página sin pasar por Loading',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => MediaPage(assets: <MediaAsset>[_c], nextCursor: ''),
          );
          return build(repo, _MockPicker());
        },
        seed: () => MediaGalleryLoaded(
          items: <MediaAsset>[_a, _b],
          nextCursor: 'cur-1',
        ),
        act: (b) => b.add(const MediaGalleryRefreshRequested()),
        expect: () => <MediaGalleryState>[
          // Señal transitoria: la lista visible se mantiene mientras refresca
          // (NO pasa por Loading, que la vaciaría).
          MediaGalleryLoaded(
            items: <MediaAsset>[_a, _b],
            nextCursor: 'cur-1',
            isRefreshing: true,
          ),
          MediaGalleryLoaded(items: <MediaAsset>[_c], nextCursor: ''),
        ],
      );

      // Caso común: refrescar sin que cambien los datos. El resultado iguala al
      // estado actual; sin la señal transitoria `isRefreshing`, el `emit` final
      // se descartaría por igualdad y un `firstWhere` esperando un cambio
      // quedaría colgado (RefreshIndicator girando para siempre).
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'datos sin cambios ⇒ igual emite (isRefreshing true→false), no se cuelga',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => MediaPage(assets: <MediaAsset>[_a], nextCursor: ''),
          );
          return build(repo, _MockPicker());
        },
        seed: () => MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: ''),
        act: (b) => b.add(const MediaGalleryRefreshRequested()),
        expect: () => <MediaGalleryState>[
          MediaGalleryLoaded(
            items: <MediaAsset>[_a],
            nextCursor: '',
            isRefreshing: true,
          ),
          MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: ''),
        ],
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'desde Initial cae a primera carga (Loading + Loaded)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => MediaPage(assets: <MediaAsset>[_a], nextCursor: ''),
          );
          return build(repo, _MockPicker());
        },
        act: (b) => b.add(const MediaGalleryRefreshRequested()),
        expect: () => <MediaGalleryState>[
          const MediaGalleryLoading(),
          MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: ''),
        ],
      );
    });

    group('MediaGalleryUploadRequested', () {
      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'pick cancelado (null) ⇒ no-op: no sube ni re-lista',
        build: () {
          _lastRepo = _MockRepo();
          final picker = _MockPicker();
          when(() => picker.pick()).thenAnswer((_) async => null);
          return build(_lastRepo, picker);
        },
        seed: () => MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: ''),
        act: (b) => b.add(const MediaGalleryUploadRequested()),
        expect: () => <MediaGalleryState>[],
        verify: (_) {
          verifyNever(
            () => _lastRepo.upload(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
            ),
          );
        },
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'éxito: isUploading durante la subida, luego re-lista con metadata del servidor',
        build: () {
          final repo = _MockRepo();
          final picker = _MockPicker();
          when(() => picker.pick()).thenAnswer((_) async => _picked);
          when(
            () => repo.upload(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
            ),
          ).thenAnswer(
            (_) async => const UploadedMedia(ref: 'media/c', previewUrl: null),
          );
          when(
            () => repo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                MediaPage(assets: <MediaAsset>[_c, _a], nextCursor: ''),
          );
          return build(repo, picker);
        },
        seed: () => MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: ''),
        act: (b) => b.add(const MediaGalleryUploadRequested()),
        expect: () => <MediaGalleryState>[
          MediaGalleryLoaded(
            items: <MediaAsset>[_a],
            nextCursor: '',
            isUploading: true,
          ),
          MediaGalleryLoaded(items: <MediaAsset>[_c, _a], nextCursor: ''),
        ],
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'sube los bytes y filename del PickedMedia',
        build: () {
          _lastRepo = _MockRepo();
          final picker = _MockPicker();
          when(() => picker.pick()).thenAnswer((_) async => _picked);
          when(
            () => _lastRepo.upload(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
            ),
          ).thenAnswer(
            (_) async => const UploadedMedia(ref: 'media/c', previewUrl: null),
          );
          when(
            () => _lastRepo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                const MediaPage(assets: <MediaAsset>[], nextCursor: ''),
          );
          return build(_lastRepo, picker);
        },
        seed: () =>
            const MediaGalleryLoaded(items: <MediaAsset>[], nextCursor: ''),
        act: (b) => b.add(const MediaGalleryUploadRequested()),
        verify: (_) {
          verify(
            () => _lastRepo.upload(bytes: _picked.bytes, filename: 'new.png'),
          ).called(1);
        },
      );

      blocTest<MediaGalleryBloc, MediaGalleryState>(
        'fallo de subida: uploadError transitorio en Loaded, NO Failed (lista intacta)',
        build: () {
          _lastRepo = _MockRepo();
          final picker = _MockPicker();
          when(() => picker.pick()).thenAnswer((_) async => _picked);
          when(
            () => _lastRepo.upload(
              bytes: any(named: 'bytes'),
              filename: any(named: 'filename'),
            ),
          ).thenThrow(const MediaTooLargeFailure());
          return build(_lastRepo, picker);
        },
        seed: () =>
            MediaGalleryLoaded(items: <MediaAsset>[_a], nextCursor: 'cur-1'),
        act: (b) => b.add(const MediaGalleryUploadRequested()),
        expect: () => <MediaGalleryState>[
          MediaGalleryLoaded(
            items: <MediaAsset>[_a],
            nextCursor: 'cur-1',
            isUploading: true,
          ),
          MediaGalleryLoaded(
            items: <MediaAsset>[_a],
            nextCursor: 'cur-1',
            uploadError: const MediaTooLargeFailure(),
          ),
        ],
        verify: (_) {
          // En fallo de subida no se re-lista.
          verifyNever(
            () => _lastRepo.listAssets(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );
    });
  });
}

/// Repo capturado por la closure de `build` para aserciones `verify` en tests
/// que no pueden alcanzar el mock desde el bloc (el bloc no lo expone).
late _MockRepo _lastRepo;

/// Compuerta para retener una petición de listado en vuelo (guarda de
/// concurrencia de load-more).
late Completer<MediaPage> _gate;
