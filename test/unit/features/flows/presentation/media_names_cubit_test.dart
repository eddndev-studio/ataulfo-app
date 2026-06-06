import 'package:ataulfo/features/flows/presentation/bloc/media_names_cubit.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/media/domain/failures/media_failure.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMediaRepo extends Mock implements MediaRepository {}

MediaAsset _asset(String ref, {String filename = 'f.bin', String alias = ''}) =>
    MediaAsset(
      ref: ref,
      previewUrl: null,
      filename: filename,
      alias: alias,
      contentType: 'application/octet-stream',
      size: 1,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late _MockMediaRepo repo;

  setUp(() {
    repo = _MockMediaRepo();
  });

  test(
    'load() recorre todas las páginas y mapea ref→displayName (alias-aware)',
    () async {
      // Página 1 con nextCursor → fuerza una segunda llamada con ese cursor.
      when(() => repo.listAssets(cursor: null)).thenAnswer(
        (_) async => MediaPage(
          assets: <MediaAsset>[
            _asset('tenant/o/media/a.ogg', filename: 'a.ogg', alias: 'Saludo'),
            _asset('tenant/o/media/b.png', filename: 'foto.png'),
          ],
          nextCursor: 'CUR2',
        ),
      );
      when(() => repo.listAssets(cursor: 'CUR2')).thenAnswer(
        (_) async => MediaPage(
          assets: <MediaAsset>[
            _asset(
              'tenant/o/media/c.pdf',
              filename: 'doc.pdf',
              alias: 'Manual',
            ),
          ],
          nextCursor: '',
        ),
      );

      final cubit = MediaNamesCubit(repo: repo);
      await cubit.load();

      expect(cubit.state.loaded, isTrue);
      // Alias gana sobre filename (displayName); sin alias usa el filename.
      expect(cubit.state.nameFor('tenant/o/media/a.ogg'), 'Saludo');
      expect(cubit.state.nameFor('tenant/o/media/b.png'), 'foto.png');
      expect(cubit.state.nameFor('tenant/o/media/c.pdf'), 'Manual');
      // Recorrió ambas páginas.
      verify(() => repo.listAssets(cursor: null)).called(1);
      verify(() => repo.listAssets(cursor: 'CUR2')).called(1);

      await cubit.close();
    },
  );

  test('nameFor de un ref desconocido ⇒ null', () async {
    when(() => repo.listAssets(cursor: null)).thenAnswer(
      (_) async => MediaPage(
        assets: <MediaAsset>[_asset('tenant/o/media/a.ogg', alias: 'A')],
        nextCursor: '',
      ),
    );

    final cubit = MediaNamesCubit(repo: repo);
    await cubit.load();

    expect(cubit.state.nameFor('tenant/o/media/desconocido.ogg'), isNull);
    await cubit.close();
  });

  test(
    'falla del catálogo ⇒ loaded=true con mapa vacío (la lista cae al respaldo)',
    () async {
      when(
        () => repo.listAssets(cursor: null),
      ).thenThrow(const MediaNetworkFailure());

      final cubit = MediaNamesCubit(repo: repo);
      await cubit.load();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.namesByRef, isEmpty);
      expect(cubit.state.nameFor('tenant/o/media/a.ogg'), isNull);
      await cubit.close();
    },
  );
}
