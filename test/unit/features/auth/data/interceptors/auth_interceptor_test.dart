import 'dart:async';
import 'dart:convert';

import 'package:agentic/core/storage/secure_kv_store.dart';
import 'package:agentic/features/auth/data/datasources/auth_datasource.dart';
import 'package:agentic/features/auth/data/interceptors/auth_interceptor.dart';
import 'package:agentic/features/auth/data/repositories/token_storage.dart';
import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:agentic/features/auth/domain/failures/auth_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// SecureKvStore en memoria — los tests del interceptor no necesitan
/// Keystore real; TokenStorage por encima sigue siendo el real.
class _MemKv implements SecureKvStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _MockAuthDs extends Mock implements AuthDatasource {}

typedef _Handler = Future<ResponseBody> Function(RequestOptions);

/// Snapshot inmutable de un request en el instante en que llegó al transporte.
/// Necesario porque Dio reusa el mismo `RequestOptions` entre primer fetch
/// y retry: sin snapshot, una mutación posterior (onRequest del retry)
/// reescribiría lo capturado al primer hit y los asserts perderían historia.
class _CapturedRequest {
  _CapturedRequest({required this.path, required this.headers});

  final String path;
  final Map<String, dynamic> headers;
}

/// Adapter HTTP fake: intercepta lo que Dio dispara realmente al transporte
/// (después de los interceptors). Permite afirmar headers del request final
/// y simular respuestas/errores sin tocar red.
class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this._handler);

  _Handler _handler;
  final List<_CapturedRequest> captured = <_CapturedRequest>[];

  set handler(_Handler h) => _handler = h;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    captured.add(
      _CapturedRequest(
        path: options.path,
        headers: Map<String, dynamic>.from(options.headers),
      ),
    );
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(int status, Map<String, dynamic> json) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );

void main() {
  late TokenStorage storage;
  late _MockAuthDs refreshDs;
  late _MockHttpAdapter adapter;
  late Dio dio;
  late int unrecoverableCalls;

  setUp(() {
    storage = TokenStorage(_MemKv());
    refreshDs = _MockAuthDs();
    adapter = _MockHttpAdapter(
      (_) async => _jsonBody(200, <String, dynamic>{}),
    );
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.httpClientAdapter = adapter;
    unrecoverableCalls = 0;
    dio.interceptors.add(
      AuthInterceptor(
        retryDio: dio,
        storage: storage,
        refreshDatasource: refreshDs,
        onUnrecoverable: () async {
          unrecoverableCalls += 1;
        },
      ),
    );
  });

  group('AuthInterceptor.onRequest', () {
    test(
      'con tokens persistidos: agrega Authorization Bearer <access>',
      () async {
        await storage.save(
          const AuthTokens(
            accessToken: 'ACCESS-1',
            refreshToken: 'r',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        await dio.get<dynamic>('/bots');

        expect(adapter.captured, hasLength(1));
        expect(
          adapter.captured.first.headers['Authorization'],
          'Bearer ACCESS-1',
        );
      },
    );

    test('sin tokens persistidos: no agrega Authorization', () async {
      await dio.get<dynamic>('/health');

      expect(adapter.captured, hasLength(1));
      expect(
        adapter.captured.first.headers.containsKey('Authorization'),
        isFalse,
      );
      // onUnrecoverable NO se invoca por falta de tokens — el interceptor no
      // decide qué ruta exige auth; cualquier 401 posterior lo gestionará.
      expect(unrecoverableCalls, 0);
    });
  });

  group('AuthInterceptor.onError 401 → refresh happy path', () {
    test(
      'refresca, persiste el par nuevo y reintenta con el access FRESCO',
      () async {
        await storage.save(
          const AuthTokens(
            accessToken: 'OLD-ACCESS',
            refreshToken: 'OLD-REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        var call = 0;
        adapter.handler = (options) async {
          call += 1;
          if (call == 1) {
            return _jsonBody(401, <String, dynamic>{});
          }
          return _jsonBody(200, <String, dynamic>{'ok': true});
        };

        when(() => refreshDs.refresh('OLD-REFRESH')).thenAnswer(
          (_) async => const AuthTokens(
            accessToken: 'NEW-ACCESS',
            refreshToken: 'NEW-REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        final res = await dio.get<Map<String, dynamic>>('/bots/abc');

        expect(res.statusCode, 200);
        expect(res.data, <String, dynamic>{'ok': true});
        verify(() => refreshDs.refresh('OLD-REFRESH')).called(1);

        // Asserción clave: el RETRY lleva el access nuevo, no el viejo
        // de err.requestOptions.headers. Lo verifica sobre el RequestOptions
        // que llegó al transporte (después de onRequest del retry).
        expect(adapter.captured, hasLength(2));
        expect(
          adapter.captured[0].headers['Authorization'],
          'Bearer OLD-ACCESS',
        );
        expect(
          adapter.captured[1].headers['Authorization'],
          'Bearer NEW-ACCESS',
        );

        // El storage quedó con el par rotado.
        final persisted = await storage.read();
        expect(
          persisted,
          const AuthTokens(
            accessToken: 'NEW-ACCESS',
            refreshToken: 'NEW-REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        expect(unrecoverableCalls, 0);
      },
    );
  });

  group('AuthInterceptor.onError 401 con refresh fallido', () {
    test(
      'purga storage, invoca onUnrecoverable y propaga el 401 original',
      () async {
        await storage.save(
          const AuthTokens(
            accessToken: 'OLD-ACCESS',
            refreshToken: 'REVOKED-REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        adapter.handler = (_) async => _jsonBody(401, <String, dynamic>{});
        when(
          () => refreshDs.refresh('REVOKED-REFRESH'),
        ).thenThrow(const InvalidCredentialsFailure());

        await expectLater(
          dio.get<dynamic>('/bots/abc'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        // No hubo retry: solo el hit original llegó al transporte.
        expect(adapter.captured, hasLength(1));
        // Storage purgado tras refresh fallido.
        expect(await storage.read(), isNull);
        // Señal al exterior emitida exactamente una vez.
        expect(unrecoverableCalls, 1);
        verify(() => refreshDs.refresh('REVOKED-REFRESH')).called(1);
      },
    );
  });

  group('AuthInterceptor.onError non-401 pass-through', () {
    test(
      '500 con tokens en storage: propaga sin tocar refresh ni storage',
      () async {
        await storage.save(
          const AuthTokens(
            accessToken: 'ACCESS',
            refreshToken: 'REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        adapter.handler = (_) async => _jsonBody(500, <String, dynamic>{});

        await expectLater(
          dio.get<dynamic>('/bots/abc'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              500,
            ),
          ),
        );

        verifyNever(() => refreshDs.refresh(any<String>()));
        expect(await storage.read(), isNotNull);
        expect(unrecoverableCalls, 0);
        expect(adapter.captured, hasLength(1));
      },
    );

    test('timeout sin response: propaga sin intentar refresh', () async {
      await storage.save(
        const AuthTokens(
          accessToken: 'ACCESS',
          refreshToken: 'REFRESH',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );

      adapter.handler = (options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      };

      await expectLater(
        dio.get<dynamic>('/bots/abc'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );

      verifyNever(() => refreshDs.refresh(any<String>()));
      expect(await storage.read(), isNotNull);
      expect(unrecoverableCalls, 0);
    });
  });

  group('AuthInterceptor concurrencia — un solo refresh para N 401', () {
    test(
      'dos requests 401 simultáneos comparten un único refresh y retransmiten con access fresco',
      () async {
        await storage.save(
          const AuthTokens(
            accessToken: 'OLD-ACCESS',
            refreshToken: 'OLD-REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        // Quien lleva OLD-ACCESS recibe 401; quien lleva el access nuevo (o
        // cualquier otro) recibe 200. Más robusto que contar invocaciones —
        // no depende del orden en que se sirven los dos requests paralelos.
        adapter.handler = (options) async {
          if (options.headers['Authorization'] == 'Bearer OLD-ACCESS') {
            return _jsonBody(401, <String, dynamic>{});
          }
          return _jsonBody(200, <String, dynamic>{'path': options.path});
        };

        final gate = Completer<AuthTokens>();
        when(
          () => refreshDs.refresh('OLD-REFRESH'),
        ).thenAnswer((_) => gate.future);

        final f1 = dio.get<dynamic>('/a');
        final f2 = dio.get<dynamic>('/b');

        // Drena event loop para que ambos requests hagan su primer fetch,
        // reciban 401 y entren a onError ANTES de que el Completer del
        // refresh complete. Sin esto la verificación de "refresh llamado 1
        // vez" puede ser racy.
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        verify(() => refreshDs.refresh('OLD-REFRESH')).called(1);

        gate.complete(
          const AuthTokens(
            accessToken: 'NEW-ACCESS',
            refreshToken: 'NEW-REFRESH',
            tokenType: 'Bearer',
            expiresInSeconds: 900,
          ),
        );

        final r1 = await f1;
        final r2 = await f2;

        expect(r1.statusCode, 200);
        expect(r2.statusCode, 200);

        // 2 originales + 2 retries = 4 hits totales en el transporte.
        expect(adapter.captured, hasLength(4));
        // Los retries (los últimos dos) llevan el access fresco — sin
        // importar el orden en que se sirvieron.
        final retryAuths = <Object?>[
          adapter.captured[2].headers['Authorization'],
          adapter.captured[3].headers['Authorization'],
        ];
        expect(retryAuths, everyElement('Bearer NEW-ACCESS'));

        // El refresh siguió siendo una sola vez incluso después de drenar
        // toda la cadena.
        verifyNoMoreInteractions(refreshDs);

        expect(unrecoverableCalls, 0);
      },
    );
  });

  group('AuthInterceptor — retry-loop guard', () {
    test('si el retry post-refresh vuelve a 401, NO dispara segundo refresh; '
        'propaga el 401 al llamador', () async {
      await storage.save(
        const AuthTokens(
          accessToken: 'OLD-ACCESS',
          refreshToken: 'OLD-REFRESH',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );

      // Todos los hits responden 401, sin importar el access que lleven —
      // simula desincronización del servidor: el refresh devuelve un par
      // nuevo, pero el servidor sigue rechazando 401. Sin guarda, esto
      // entra en bucle (cada retry vuelve a onError, dispara refresh otra
      // vez, etc.).
      adapter.handler = (_) async => _jsonBody(401, <String, dynamic>{});

      when(() => refreshDs.refresh(any<String>())).thenAnswer(
        (_) async => const AuthTokens(
          accessToken: 'NEW-ACCESS',
          refreshToken: 'NEW-REFRESH',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );

      await expectLater(
        dio.get<dynamic>('/protected'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // El refresh corrió UNA sola vez. El retry post-refresh recibió 401
      // y el interceptor lo dejó pasar sin volver a refrescar.
      verify(() => refreshDs.refresh(any<String>())).called(1);
      verifyNoMoreInteractions(refreshDs);

      // 2 hits: el original + 1 retry. No hay tercer hit (que sería el
      // síntoma del bucle).
      expect(adapter.captured, hasLength(2));
    });
  });
}
