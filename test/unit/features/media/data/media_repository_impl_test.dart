import 'dart:typed_data';

import 'package:ataulfo/features/media/data/datasources/media_datasource.dart';
import 'package:ataulfo/features/media/data/repositories/media_repository_impl.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements MediaDatasource {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late _MockDatasource ds;
  late MediaRepositoryImpl repo;

  setUp(() {
    ds = _MockDatasource();
    repo = MediaRepositoryImpl(datasource: ds);
  });

  test('upload delega al datasource con bytes + filename', () async {
    final bytes = Uint8List.fromList(<int>[1, 2]);
    when(
      () => ds.upload(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((_) async => const UploadedMedia(ref: 'r', previewUrl: 'u'));

    final result = await repo.upload(bytes: bytes, filename: 'f.png');

    expect(result.ref, 'r');
    verify(() => ds.upload(bytes: bytes, filename: 'f.png')).called(1);
  });

  test('listAssets delega al datasource con cursor + limit', () async {
    const page = MediaPage(assets: <MediaAsset>[], nextCursor: '');
    when(
      () => ds.listAssets(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => page);

    final result = await repo.listAssets(cursor: 'c', limit: 10);

    expect(result, page);
    verify(() => ds.listAssets(cursor: 'c', limit: 10)).called(1);
  });

  test('delete delega al datasource con el ref', () async {
    when(() => ds.delete(any())).thenAnswer((_) async {});

    await repo.delete('tenant/org/media/x.png');

    verify(() => ds.delete('tenant/org/media/x.png')).called(1);
  });

  test('invalidate es no-op: no toca el datasource ni lanza', () {
    expect(repo.invalidate, returnsNormally);
    verifyZeroInteractions(ds);
  });
}
