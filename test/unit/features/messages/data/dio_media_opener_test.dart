import 'dart:io';

import 'package:ataulfo/features/messages/data/media/dio_media_opener.dart';
import 'package:ataulfo/features/messages/domain/repositories/media_opener.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late Directory tmp;
  late List<String> opened;
  late bool openResult;

  setUp(() async {
    dio = _MockDio();
    tmp = await Directory.systemTemp.createTemp('opener_test');
    opened = <String>[];
    openResult = true;
    registerFallbackValue(Options());
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  DioMediaOpener build() => DioMediaOpener(
    dio: dio,
    cacheDir: () async => tmp,
    openFile: (path) async {
      opened.add(path);
      return openResult;
    },
  );

  void stubGet(String url, List<int> bytes, {String? contentType}) {
    when(
      () => dio.get<List<int>>(url, options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response<List<int>>(
        data: bytes,
        statusCode: 200,
        requestOptions: RequestOptions(path: url),
        headers: Headers.fromMap(<String, List<String>>{
          if (contentType != null) 'content-type': <String>[contentType],
        }),
      ),
    );
  }

  test('descarga, escribe el archivo y lo abre con la app externa', () async {
    stubGet('https://r2/firmada/doc123?sig=x', <int>[
      1,
      2,
      3,
    ], contentType: 'application/pdf');

    await build().open(url: 'https://r2/firmada/doc123?sig=x');

    expect(opened, hasLength(1));
    final file = File(opened.single);
    expect(await file.readAsBytes(), <int>[1, 2, 3]);
    // Sin extensión en el path: se deriva del Content-Type.
    expect(opened.single, endsWith('.pdf'));
  });

  test('conserva la extensión del path cuando ya viene en la URL', () async {
    stubGet('https://r2/firmada/video_promo.mp4?sig=x', <int>[9]);

    await build().open(url: 'https://r2/firmada/video_promo.mp4?sig=x');

    expect(opened.single, endsWith('video_promo.mp4'));
  });

  test('si ninguna app pudo abrirlo, lanza MediaOpenException', () async {
    stubGet('https://r2/f/x', <int>[1], contentType: 'application/pdf');
    openResult = false;

    expect(
      () => build().open(url: 'https://r2/f/x'),
      throwsA(isA<MediaOpenException>()),
    );
  });

  test(
    'un fallo de descarga (red/firma vencida) lanza MediaOpenException',
    () async {
      when(
        () => dio.get<List<int>>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(requestOptions: RequestOptions(path: 'https://r2/f/x')),
      );

      expect(
        () => build().open(url: 'https://r2/f/x'),
        throwsA(isA<MediaOpenException>()),
      );
      expect(opened, isEmpty);
    },
  );
}
