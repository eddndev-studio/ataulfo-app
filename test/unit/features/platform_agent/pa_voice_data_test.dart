import 'dart:async';

import 'package:ataulfo/features/platform_agent/data/datasources/pa_turn_timeout.dart';
import 'package:ataulfo/features/platform_agent/data/datasources/platform_agent_datasource.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _assistant(String path) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: <String, dynamic>{
        'id': 'a1',
        'conversation_id': 'c1',
        'role': 'assistant',
        'content': 'te escuché',
        'created_at': '2026-06-12T10:00:01.000Z',
      },
    );

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: code,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  setUpAll(() {
    registerFallbackValue(FormData());
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioPlatformAgentDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioPlatformAgentDatasource(dio);
  });

  const path = '/platform-agent/conversations/c1/audio';

  test('sendAudio POSTea multipart (part "audio", voice.ogg) y devuelve el '
      'turno assistant', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        path,
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => _assistant(path));

    final m = await ds.sendAudio(
      conversationId: 'c1',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    );

    expect(m.role, 'assistant');
    expect(m.content, 'te escuché');

    final captured =
        verify(
              () => dio.post<Map<String, dynamic>>(
                path,
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
                cancelToken: any(named: 'cancelToken'),
              ),
            ).captured.single
            as FormData;
    expect(captured.files.single.key, 'audio');
    expect(captured.files.single.value.filename, 'voice.ogg');
  });

  test(
    'sendAudio espera el presupuesto del turno (receiveTimeout largo)',
    () async {
      Options? opts;
      when(
        () => dio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((inv) async {
        opts = inv.namedArguments[#options] as Options?;
        return _assistant(path);
      });

      await ds.sendAudio(
        conversationId: 'c1',
        bytes: Uint8List.fromList(<int>[1]),
      );
      expect(opts?.receiveTimeout, paTurnReceiveTimeout);
    },
  );

  test('cancelInFlight aborta el POST de audio en vuelo', () async {
    CancelToken? captured;
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((inv) {
      captured = inv.namedArguments[#cancelToken] as CancelToken?;
      final completer = Completer<Response<Map<String, dynamic>>>();
      captured!.whenCancel.then(
        (_) => completer.completeError(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.cancel,
          ),
        ),
      );
      return completer.future;
    });

    final future = ds.sendAudio(
      conversationId: 'c1',
      bytes: Uint8List.fromList(<int>[1]),
    );
    await Future<void>.delayed(Duration.zero);
    ds.cancelInFlight();
    await expectLater(future, throwsA(isA<PaFailure>()));
    expect(captured!.isCancelled, isTrue);
  });

  test('mapea 413/415/502 a fallos tipados', () async {
    for (final entry in <int, Type>{
      413: PaAttachmentTooLargeFailure,
      415: PaAttachmentUnsupportedFailure,
      502: PaEngineFailure,
    }.entries) {
      when(
        () => dio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(_status(entry.key));
      await expectLater(
        () => ds.sendAudio(
          conversationId: 'c1',
          bytes: Uint8List.fromList(<int>[1]),
        ),
        throwsA(predicate((e) => e.runtimeType == entry.value)),
      );
    }
  });
}
