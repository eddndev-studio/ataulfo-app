import 'dart:convert';

import 'package:ataulfo/features/trainer/data/datasources/preview_datasource.dart';
import 'package:ataulfo/features/trainer/domain/entities/preview_attachment.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  test('sendMessage manda los adjuntos como base64 {name, data}', () async {
    final dio = _MockDio();
    final ds = DioPreviewDatasource(dio);
    when(
      () => dio.post<Map<String, dynamic>>(
        '/templates/t1/preview/messages',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
        data: <String, dynamic>{'items': <dynamic>[], 'iterations': 1},
      ),
    );

    await ds.sendMessage(
      templateId: 't1',
      content: 'mira',
      attachments: <PreviewAttachment>[
        PreviewAttachment(
          name: 'foto.png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ],
    );

    final captured =
        verify(
              () => dio.post<Map<String, dynamic>>(
                '/templates/t1/preview/messages',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    final atts = captured['attachments'] as List<dynamic>;
    final att = atts.single as Map<String, dynamic>;
    expect(att['name'], 'foto.png');
    expect(att['data'], base64Encode(<int>[1, 2, 3]));
  });

  test('sin adjuntos el body conserva el shape histórico', () async {
    final dio = _MockDio();
    final ds = DioPreviewDatasource(dio);
    when(
      () => dio.post<Map<String, dynamic>>(
        '/templates/t1/preview/messages',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
        data: <String, dynamic>{'items': <dynamic>[], 'iterations': 1},
      ),
    );

    await ds.sendMessage(templateId: 't1', content: 'hola');

    final captured =
        verify(
              () => dio.post<Map<String, dynamic>>(
                '/templates/t1/preview/messages',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured.containsKey('attachments'), isFalse);
  });
}
