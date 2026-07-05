import 'dart:async';

import 'package:ataulfo/features/trainer/data/datasources/trainer_datasource.dart';
import 'package:ataulfo/features/trainer/data/datasources/turn_timeout.dart';
import 'package:ataulfo/features/trainer/data/dto/trainer_dtos.dart';
import 'package:ataulfo/features/trainer/domain/failures/trainer_failure.dart';
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
  group('TrainerMessageDto nota de voz', () {
    test('parsea audio_ref/transcript_status/transcript del user de voz', () {
      final m = TrainerMessageDto.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'role': 'user',
        'content': 'hola entrenador',
        'created_at': '2026-06-10T10:00:00.000Z',
        'audio_ref': 'tenant/org/media/v1.ogg',
        'transcript_status': 'done',
        'transcript': 'hola entrenador',
      }).toEntity();
      expect(m.audioRef, 'tenant/org/media/v1.ogg');
      expect(m.transcriptStatus, 'done');
      expect(m.transcript, 'hola entrenador');
      expect(m.isVoiceNote, isTrue);
    });

    test('sin campos de audio (wire viejo/turno normal) degradan a vacío', () {
      final m = TrainerMessageDto.fromJson(<String, dynamic>{
        'id': 'm2',
        'conversation_id': 'c1',
        'role': 'assistant',
        'content': 'listo',
        'created_at': '2026-06-10T10:00:00.000Z',
      }).toEntity();
      expect(m.audioRef, '');
      expect(m.transcriptStatus, '');
      expect(m.transcript, '');
      expect(m.isVoiceNote, isFalse);
    });

    test('campos de audio con tipo inesperado se ignoran (defensivo)', () {
      final m = TrainerMessageDto.fromJson(<String, dynamic>{
        'id': 'm3',
        'conversation_id': 'c1',
        'role': 'user',
        'content': '',
        'created_at': '2026-06-10T10:00:00.000Z',
        'audio_ref': 42,
        'transcript_status': <String, dynamic>{},
        'transcript': true,
      }).toEntity();
      expect(m.audioRef, '');
      expect(m.transcriptStatus, '');
      expect(m.transcript, '');
    });
  });

  group('DioTrainerDatasource.sendAudio', () {
    setUpAll(() {
      registerFallbackValue(FormData());
      registerFallbackValue(Options());
    });

    late _MockDio dio;
    late DioTrainerDatasource ds;

    setUp(() {
      dio = _MockDio();
      ds = DioTrainerDatasource(dio);
    });

    const path = '/templates/t1/trainer/conversations/c1/audio';

    test('POSTea multipart (part "audio", voice.ogg) y devuelve el turno '
        'assistant', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          path,
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _assistant(path));

      final m = await ds.sendAudio(
        templateId: 't1',
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

    test('espera el presupuesto del turno (receiveTimeout largo)', () async {
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
        templateId: 't1',
        conversationId: 'c1',
        bytes: Uint8List.fromList(<int>[1]),
      );
      expect(opts?.receiveTimeout, turnReceiveTimeout);
    });

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
        templateId: 't1',
        conversationId: 'c1',
        bytes: Uint8List.fromList(<int>[1]),
      );
      await Future<void>.delayed(Duration.zero);
      ds.cancelInFlight();
      await expectLater(future, throwsA(isA<TrainerFailure>()));
      expect(captured!.isCancelled, isTrue);
    });

    test('mapea 413/415/502 a fallos tipados', () async {
      for (final entry in <int, Type>{
        413: TrainerAttachmentTooLargeFailure,
        415: TrainerAttachmentUnsupportedFailure,
        502: TrainerEngineFailure,
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
            templateId: 't1',
            conversationId: 'c1',
            bytes: Uint8List.fromList(<int>[1]),
          ),
          throwsA(predicate((e) => e.runtimeType == entry.value)),
        );
      }
    });
  });
}
