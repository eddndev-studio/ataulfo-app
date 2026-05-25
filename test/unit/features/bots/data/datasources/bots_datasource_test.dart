import 'package:agentic/features/bots/data/datasources/bots_datasource.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioBotsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotsDatasource(dio);
  });

  Response<List<dynamic>> resp(int status, {List<dynamic>? body}) =>
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/bots'),
        statusCode: status,
        data: body,
      );

  Response<Map<String, dynamic>> respMap(
    int status, {
    Map<String, dynamic>? body,
    String path = '/bots/b1',
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {String path = '/bots'}) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> botJson({
    String id = 'b1',
    String channel = 'WA_UNOFFICIAL',
    bool paused = false,
  }) => <String, dynamic>{
    'id': id,
    'org_id': 'o1',
    'template_id': 't1',
    'name': 'Soporte',
    'channel': channel,
    'identifier': '52155...',
    'version': 3,
    'paused': paused,
    'ai_disabled': false,
  };

  group('DioBotsDatasource.list', () {
    test('200 con [botResp...] → List<Bot>', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            botJson(),
            botJson(id: 'b2', channel: 'WABA', paused: true),
          ],
        ),
      );

      final bots = await ds.list();

      expect(bots, hasLength(2));
      expect(bots[0].id, 'b1');
      expect(bots[0].channel, BotChannel.waUnofficial);
      expect(bots[1].id, 'b2');
      expect(bots[1].channel, BotChannel.waba);
      expect(bots[1].paused, isTrue);
      verify(() => dio.get<List<dynamic>>('/bots')).called(1);
    });

    test('200 con [] → List<Bot> vacía', () async {
      when(
        () => dio.get<List<dynamic>>('/bots'),
      ).thenAnswer((_) async => resp(200, body: <dynamic>[]));

      expect(await ds.list(), isEmpty);
    });

    test('timeout → BotsTimeoutFailure', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(ds.list(), throwsA(isA<BotsTimeoutFailure>()));
    });

    test('sin conexión → BotsNetworkFailure', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(ds.list(), throwsA(isA<BotsNetworkFailure>()));
    });

    test('403 → BotsForbiddenFailure', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenThrow(badResponse(403));

      await expectLater(ds.list(), throwsA(isA<BotsForbiddenFailure>()));
    });

    test('500 → BotsServerFailure', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenThrow(badResponse(500));

      await expectLater(ds.list(), throwsA(isA<BotsServerFailure>()));
    });

    test('503 → BotsServerFailure (cubre 5xx genérico)', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenThrow(badResponse(503));

      await expectLater(ds.list(), throwsA(isA<BotsServerFailure>()));
    });

    test('418 (no contemplado) → UnknownBotsFailure', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenThrow(badResponse(418));

      await expectLater(ds.list(), throwsA(isA<UnknownBotsFailure>()));
    });

    test('body nulo → UnknownBotsFailure (contrato roto)', () async {
      when(
        () => dio.get<List<dynamic>>('/bots'),
      ).thenAnswer((_) async => resp(200));

      await expectLater(ds.list(), throwsA(isA<UnknownBotsFailure>()));
    });

    test('body con elemento malformado → UnknownBotsFailure', () async {
      when(() => dio.get<List<dynamic>>('/bots')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            <String, dynamic>{'id': 'x'},
          ], // faltan claves
        ),
      );

      await expectLater(ds.list(), throwsA(isA<UnknownBotsFailure>()));
    });
  });

  group('DioBotsDatasource.byId', () {
    test('200 con botResp → Bot', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1')).thenAnswer(
        (_) async => respMap(
          200,
          body: botJson(id: 'b1', channel: 'WA_UNOFFICIAL'),
        ),
      );

      final bot = await ds.byId('b1');

      expect(bot.id, 'b1');
      expect(bot.channel, BotChannel.waUnofficial);
      expect(bot.paused, isFalse);
      verify(() => dio.get<Map<String, dynamic>>('/bots/b1')).called(1);
    });

    test('404 → BotsNotFoundFailure', () async {
      // El detalle introduce la única variante nueva del mapping respecto al
      // listado: un ID inválido / borrado responde 404 puntual y el bloc
      // debe poder distinguirlo del 5xx genérico para el copy de error.
      when(
        () => dio.get<Map<String, dynamic>>('/bots/missing'),
      ).thenThrow(badResponse(404, path: '/bots/missing'));

      await expectLater(
        ds.byId('missing'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });

    test('403 → BotsForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1'),
      ).thenThrow(badResponse(403, path: '/bots/b1'));

      await expectLater(ds.byId('b1'), throwsA(isA<BotsForbiddenFailure>()));
    });

    test('timeout → BotsTimeoutFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(ds.byId('b1'), throwsA(isA<BotsTimeoutFailure>()));
    });

    test('sin conexión → BotsNetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(ds.byId('b1'), throwsA(isA<BotsNetworkFailure>()));
    });

    test('500 → BotsServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1'),
      ).thenThrow(badResponse(500, path: '/bots/b1'));

      await expectLater(ds.byId('b1'), throwsA(isA<BotsServerFailure>()));
    });

    test('body nulo → UnknownBotsFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1'),
      ).thenAnswer((_) async => respMap(200));

      await expectLater(ds.byId('b1'), throwsA(isA<UnknownBotsFailure>()));
    });

    test('body malformado → UnknownBotsFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1')).thenAnswer(
        (_) async => respMap(200, body: <String, dynamic>{'id': 'x'}),
      );

      await expectLater(ds.byId('b1'), throwsA(isA<UnknownBotsFailure>()));
    });
  });

  group('DioBotsDatasource.create', () {
    // El cliente sólo crea bots WA_UNOFFICIAL en v1; WABA viajará cuando
    // aterrice el flujo de verificación. La firma toma BotChannel para que
    // la decisión esté en presentación, no acá.
    test(
      '201 con botResp → Bot (envía {template_id, name, channel})',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bots',
            data: any<Object?>(named: 'data'),
          ),
        ).thenAnswer((_) async => respMap(201, body: botJson(), path: '/bots'));

        final bot = await ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        );

        expect(bot.id, 'b1');
        expect(bot.templateId, 't1');
        expect(bot.channel, BotChannel.waUnofficial);
        verify(
          () => dio.post<Map<String, dynamic>>(
            '/bots',
            data: <String, dynamic>{
              'template_id': 't1',
              'name': 'Soporte',
              'channel': 'WA_UNOFFICIAL',
            },
          ),
        ).called(1);
      },
    );

    test('422 → BotsInvalidCreateFailure', () async {
      // 422 colapsa varias causas del backend (name vacío, channel
      // desconocido, template inexistente, variables inválidas). Un solo
      // cubo "Revisa los datos del bot".
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(422, path: '/bots'));

      await expectLater(
        ds.create(templateId: 't1', name: '', channel: BotChannel.waUnofficial),
        throwsA(isA<BotsInvalidCreateFailure>()),
      );
    });

    test('403 → BotsForbiddenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(403, path: '/bots'));

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<BotsForbiddenFailure>()),
      );
    });

    test('500 → BotsServerFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(500, path: '/bots'));

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<BotsServerFailure>()),
      );
    });

    test('timeout → BotsTimeoutFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots'),
          type: DioExceptionType.sendTimeout,
        ),
      );

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<BotsTimeoutFailure>()),
      );
    });

    test('sin conexión → BotsNetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<BotsNetworkFailure>()),
      );
    });

    test('409 (sin org activa, caso raro) → UnknownBotsFailure', () async {
      // El handler responde 409 si el Bearer no trae org activa; en flujo
      // normal (post-login + /auth/me) no ocurre. Colapsa a Unknown.
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(409, path: '/bots'));

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('body nulo → UnknownBotsFailure (contrato roto)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer((_) async => respMap(201, path: '/bots'));

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('body malformado → UnknownBotsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/bots',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            respMap(201, body: <String, dynamic>{'id': 'x'}, path: '/bots'),
      );

      await expectLater(
        ds.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });
  });
}
