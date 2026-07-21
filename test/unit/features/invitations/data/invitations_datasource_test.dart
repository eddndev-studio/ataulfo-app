import 'package:ataulfo/features/invitations/data/datasources/invitations_datasource.dart';
import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioInvitationsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioInvitationsDatasource(dio);
  });

  Response<List<dynamic>> listResp(int status, {List<dynamic>? body}) =>
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/workspace/invitations'),
        statusCode: status,
        data: body,
      );

  Response<void> voidResp(int status) => Response<void>(
    requestOptions: RequestOptions(path: '/workspace/invitations'),
    statusCode: status,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/workspace/invitations'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/workspace/invitations'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> invJson({
    String id = 'i1',
    String email = 'a@x.com',
    String role = 'WORKER',
    String status = 'PENDING',
  }) => <String, dynamic>{
    'id': id,
    'org_id': 'o1',
    'email': email,
    'role': role,
    'status': status,
    'bot_ids': <String>['b1'],
    'expires_at': '2026-06-01T12:00:00Z',
    'created_at': '2026-05-25T09:30:00Z',
  };

  group('DioInvitationsDatasource.list', () {
    test('200 con [...] → List<Invitation>', () async {
      when(() => dio.get<List<dynamic>>('/workspace/invitations')).thenAnswer(
        (_) async => listResp(
          200,
          body: <dynamic>[
            invJson(),
            invJson(id: 'i2', status: 'ACCEPTED'),
          ],
        ),
      );

      final list = await ds.list();

      expect(list, hasLength(2));
      expect(list[0].id, 'i1');
      expect(list[0].status, 'PENDING');
      expect(list[1].status, 'ACCEPTED');
    });

    test('200 con [] → vacía', () async {
      when(
        () => dio.get<List<dynamic>>('/workspace/invitations'),
      ).thenAnswer((_) async => listResp(200, body: <dynamic>[]));

      expect(await ds.list(), isEmpty);
    });

    test('403 → Forbidden', () async {
      when(
        () => dio.get<List<dynamic>>('/workspace/invitations'),
      ).thenThrow(badResponse(403));

      await expectLater(ds.list(), throwsA(isA<InvitationsForbiddenFailure>()));
    });

    test('500 → Server', () async {
      when(
        () => dio.get<List<dynamic>>('/workspace/invitations'),
      ).thenThrow(badResponse(500));

      await expectLater(ds.list(), throwsA(isA<InvitationsServerFailure>()));
    });

    test('body malformado → Unknown', () async {
      when(() => dio.get<List<dynamic>>('/workspace/invitations')).thenAnswer(
        (_) async => listResp(
          200,
          body: <dynamic>[
            <String, dynamic>{'id': 'i1'},
          ],
        ),
      );

      await expectLater(ds.list(), throwsA(isA<UnknownInvitationsFailure>()));
    });
  });

  Response<Map<String, dynamic>> mapResp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/workspace/invitations'),
    statusCode: status,
    data: body,
  );

  group('DioInvitationsDatasource.create', () {
    test('201 → devuelve token y envía correo, rol y canales', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => mapResp(
          201,
          body: <String, dynamic>{
            ...invJson(email: 'a@x.com', role: 'ADMIN'),
            'token': 'RAW-SHARE-TOKEN',
            'email_sent': true,
          },
        ),
      );

      final created = await ds.create('a@x.com', 'WORKER', const <String>[
        'b2',
        'b1',
      ]);

      expect(created.token, 'RAW-SHARE-TOKEN');
      expect(created.emailSent, isTrue);
      expect(created.email, 'a@x.com');
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/workspace/invitations',
          data: const <String, dynamic>{
            'email': 'a@x.com',
            'role': 'WORKER',
            'bot_ids': <String>['b2', 'b1'],
          },
        ),
      ).called(1);
    });

    test('201 con email_sent:false → degrada honesto (token igual)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => mapResp(
          201,
          body: <String, dynamic>{
            ...invJson(),
            'token': 'T',
            'email_sent': false,
          },
        ),
      );

      final created = await ds.create('a@x.com', 'ADMIN', const <String>[]);
      expect(created.token, 'T');
      expect(created.emailSent, isFalse);
    });

    test('409 → Duplicate (ya hay una PENDING para ese correo)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(409));

      await expectLater(
        ds.create('a@x.com', 'ADMIN', const <String>[]),
        throwsA(isA<InvitationsDuplicateFailure>()),
      );
    });

    test('422 → Validation', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(422));

      await expectLater(
        ds.create('a@x.com', 'ADMIN', const <String>[]),
        throwsA(isA<InvitationsValidationFailure>()),
      );
    });

    test('403 → Forbidden', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(403));

      await expectLater(
        ds.create('a@x.com', 'ADMIN', const <String>[]),
        throwsA(isA<InvitationsForbiddenFailure>()),
      );
    });

    test(
      '500 → Server (la fila pudo guardarse; el correo pudo fallar)',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(badResponse(500));

        await expectLater(
          ds.create('a@x.com', 'ADMIN', const <String>[]),
          throwsA(isA<InvitationsServerFailure>()),
        );
      },
    );
  });

  group('DioInvitationsDatasource.cancel', () {
    test('204 → completa y pega al path de la invitación', () async {
      when(
        () => dio.delete<void>(any()),
      ).thenAnswer((_) async => voidResp(204));

      await ds.cancel('i1');

      verify(() => dio.delete<void>('/workspace/invitations/i1')).called(1);
    });

    test('404 → NotFound', () async {
      when(() => dio.delete<void>(any())).thenThrow(badResponse(404));

      await expectLater(
        ds.cancel('i1'),
        throwsA(isA<InvitationsNotFoundFailure>()),
      );
    });

    test('410 → Gone (ya consumida)', () async {
      when(() => dio.delete<void>(any())).thenThrow(badResponse(410));

      await expectLater(
        ds.cancel('i1'),
        throwsA(isA<InvitationsGoneFailure>()),
      );
    });

    test('403 → Forbidden', () async {
      when(() => dio.delete<void>(any())).thenThrow(badResponse(403));

      await expectLater(
        ds.cancel('i1'),
        throwsA(isA<InvitationsForbiddenFailure>()),
      );
    });

    test('500 → Server', () async {
      when(() => dio.delete<void>(any())).thenThrow(badResponse(500));

      await expectLater(
        ds.cancel('i1'),
        throwsA(isA<InvitationsServerFailure>()),
      );
    });
  });
}
