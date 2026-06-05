import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/media/presentation/bloc/media_detail_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MediaRepository {}

final _asset = MediaAsset(
  ref: 'tenant/org/media/x.png',
  previewUrl: null,
  filename: 'x.png',
  contentType: 'image/png',
  size: 1,
  createdAt: DateTime.utc(2026),
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('estado inicial = idle con el asset dado', () {
    final c = MediaDetailCubit(repo: repo, asset: _asset);
    expect(c.state.asset, _asset);
    expect(c.state.busy, isFalse);
    expect(c.state.deleted, isFalse);
    expect(c.state.error, isNull);
  });

  blocTest<MediaDetailCubit, MediaDetailState>(
    'deleteAsset ok ⇒ [busy, deleted] y llama repo.delete con el ref',
    build: () {
      when(() => repo.delete(any())).thenAnswer((_) async {});
      return MediaDetailCubit(repo: repo, asset: _asset);
    },
    act: (c) => c.deleteAsset(),
    expect: () => <Matcher>[
      isA<MediaDetailState>().having((s) => s.busy, 'busy', isTrue),
      isA<MediaDetailState>()
          .having((s) => s.busy, 'busy', isFalse)
          .having((s) => s.deleted, 'deleted', isTrue),
    ],
    verify: (_) =>
        verify(() => repo.delete('tenant/org/media/x.png')).called(1),
  );

  blocTest<MediaDetailCubit, MediaDetailState>(
    'setAlias ok ⇒ refleja el alias normalizado del server + changed=true',
    build: () {
      // El server normaliza (trim): devuelve "Mi logo" aunque el input traiga
      // espacios. El cubit refleja el valor del server, no el crudo.
      when(
        () => repo.setAlias(any(), any()),
      ).thenAnswer((_) async => 'Mi logo');
      return MediaDetailCubit(repo: repo, asset: _asset);
    },
    act: (c) => c.setAlias('  Mi logo  '),
    expect: () => <Matcher>[
      isA<MediaDetailState>().having((s) => s.busy, 'busy', isTrue),
      isA<MediaDetailState>()
          .having((s) => s.busy, 'busy', isFalse)
          .having((s) => s.changed, 'changed', isTrue)
          .having((s) => s.asset.alias, 'asset.alias', 'Mi logo'),
    ],
    verify: (_) => verify(
      () => repo.setAlias('tenant/org/media/x.png', '  Mi logo  '),
    ).called(1),
  );

  blocTest<MediaDetailCubit, MediaDetailState>(
    'setAlias falla ⇒ [busy, error] sin changed',
    build: () {
      when(
        () => repo.setAlias(any(), any()),
      ).thenThrow(const MediaForbiddenFailure());
      return MediaDetailCubit(repo: repo, asset: _asset);
    },
    act: (c) => c.setAlias('x'),
    expect: () => <Matcher>[
      isA<MediaDetailState>().having((s) => s.busy, 'busy', isTrue),
      isA<MediaDetailState>()
          .having((s) => s.busy, 'busy', isFalse)
          .having((s) => s.changed, 'changed', isFalse)
          .having((s) => s.error, 'error', isA<MediaForbiddenFailure>()),
    ],
  );

  blocTest<MediaDetailCubit, MediaDetailState>(
    'deleteAsset falla ⇒ [busy, error] sin deleted (la página no hace pop)',
    build: () {
      when(() => repo.delete(any())).thenThrow(const MediaForbiddenFailure());
      return MediaDetailCubit(repo: repo, asset: _asset);
    },
    act: (c) => c.deleteAsset(),
    expect: () => <Matcher>[
      isA<MediaDetailState>().having((s) => s.busy, 'busy', isTrue),
      isA<MediaDetailState>()
          .having((s) => s.busy, 'busy', isFalse)
          .having((s) => s.deleted, 'deleted', isFalse)
          .having((s) => s.error, 'error', isA<MediaForbiddenFailure>()),
    ],
  );
}
