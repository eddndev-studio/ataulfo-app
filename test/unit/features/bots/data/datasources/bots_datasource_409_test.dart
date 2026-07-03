import 'package:ataulfo/features/bots/data/datasources/bots_datasource.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// Cubre el verbo `update` (PUT /bots/:id con CAS) y, en especial, el mapeo
/// 409 POR-ENDPOINT: en el PUT un 409 es conflicto de versión
/// (`BotsConflictFailure`), pero en el POST de creación un 409 (sin org
/// activa) sigue siendo `UnknownBotsFailure` — el mapeo no es global.
void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockDio dio;
  late DioBotsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotsDatasource(dio);
  });

  Map<String, dynamic> botJson() => <String, dynamic>{
    'id': 'b1',
    'org_id': 'o1',
    'template_id': 't1',
    'name': 'Soporte+',
    'channel': 'WA_UNOFFICIAL',
    'identifier': '52155...',
    'version': 4,
    'paused': true,
    'ai_disabled': false,
  };

  Response<Map<String, dynamic>> ok() => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/bots/b1'),
    statusCode: 200,
    data: botJson(),
  );

  DioException bad(int status, {String path = '/bots/b1'}) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioBotsDatasource.update', () {
    test('PUT ok → Bot; body tristate omite los campos null', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => ok());

      final bot = await ds.update(id: 'b1', paused: true, version: 3);

      expect(bot.id, 'b1');
      expect(bot.paused, isTrue);
      expect(bot.version, 4);

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/bots/b1');
      // Sólo `paused` y `version` viajan; name/ai_disabled/variable_values
      // se omiten (tristate por omisión == "no tocar").
      expect(captured[1], <String, dynamic>{'paused': true, 'version': 3});
    });

    test(
      'PUT con name + ai_disabled + variableValues serializa todo',
      () async {
        when(
          () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer((_) async => ok());

        await ds.update(
          id: 'b1',
          name: 'Soporte+',
          aiDisabled: true,
          variableValues: const <String, String>{'tono': 'formal'},
          version: 7,
        );

        final captured = verify(
          () => dio.put<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
          ),
        ).captured;
        expect(captured[0], <String, dynamic>{
          'name': 'Soporte+',
          'ai_disabled': true,
          'variable_values': <String, String>{'tono': 'formal'},
          'version': 7,
        });
      },
    );

    test('PUT con los gates de grupos serializa sólo los enviados', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => ok());

      await ds.update(id: 'b1', version: 5, groupChatsAiDisabled: true);

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      // Sólo el gate enviado + version; el gate de flujos se OMITE (tristate).
      expect(captured[0], <String, dynamic>{
        'group_chats_ai_disabled': true,
        'version': 5,
      });
    });

    test('PUT con ambos gates de grupos serializa las dos claves', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => ok());

      await ds.update(
        id: 'b1',
        version: 6,
        groupChatsAiDisabled: false,
        groupChatsFlowsDisabled: true,
      );

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], <String, dynamic>{
        'group_chats_ai_disabled': false,
        'group_chats_flows_disabled': true,
        'version': 6,
      });
    });

    test('PUT con variableValues vacío envía {} (jamás null)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => ok());

      await ds.update(
        id: 'b1',
        variableValues: const <String, String>{},
        version: 2,
      );

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      final body = captured[0] as Map<String, dynamic>;
      expect(body['variable_values'], <String, String>{});
      expect(body.containsKey('variable_values'), isTrue);
    });

    test('PUT con 409 → BotsConflictFailure (CAS de versión)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(409));

      await expectLater(
        ds.update(id: 'b1', name: 'x', version: 1),
        throwsA(isA<BotsConflictFailure>()),
      );
    });

    test('PUT con 422 → BotsInvalidCreateFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(422));

      await expectLater(
        ds.update(id: 'b1', name: '', version: 1),
        throwsA(isA<BotsInvalidCreateFailure>()),
      );
    });

    test('PUT con 404 → BotsNotFoundFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(404));

      await expectLater(
        ds.update(id: 'b1', name: 'x', version: 1),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });

    test('PUT con 403 → BotsForbiddenFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(403));

      await expectLater(
        ds.update(id: 'b1', name: 'x', version: 1),
        throwsA(isA<BotsForbiddenFailure>()),
      );
    });

    test('PUT con 5xx → BotsServerFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(bad(503));

      await expectLater(
        ds.update(id: 'b1', name: 'x', version: 1),
        throwsA(isA<BotsServerFailure>()),
      );
    });

    test('PUT body nulo → UnknownBotsFailure (contrato roto)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1'),
          statusCode: 200,
        ),
      );

      await expectLater(
        ds.update(id: 'b1', name: 'x', version: 1),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });
  });

  group('per-endpoint 409 (regresión)', () {
    test(
      'create con 409 SIGUE siendo UnknownBotsFailure, NO Conflict',
      () async {
        // El 409 del POST /bots es "sin org activa", no un CAS. El mapeo de
        // 409→Conflict vive SÓLO en el PUT; el del create no debe cambiar.
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bots',
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(bad(409, path: '/bots'));

        await expectLater(
          ds.create(
            templateId: 't1',
            name: 'Soporte',
            channel: BotChannel.waUnofficial,
          ),
          throwsA(isA<UnknownBotsFailure>()),
        );
      },
    );
  });
}
