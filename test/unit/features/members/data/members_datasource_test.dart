import 'package:ataulfo/features/members/data/datasources/members_datasource.dart';
import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioMembersDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioMembersDatasource(dio);
  });

  Response<List<dynamic>> resp(int status, {List<dynamic>? body}) =>
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/workspace/members'),
        statusCode: status,
        data: body,
      );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/workspace/members'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/workspace/members'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> memberJson({
    String id = 'm1',
    String userId = 'u1',
    String email = 'a@x.com',
    bool emailVerified = true,
    String role = 'OWNER',
  }) => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'email': email,
    'email_verified': emailVerified,
    'role': role,
  };

  group('DioMembersDatasource.list', () {
    test('200 con [memberResp...] → List<Member>', () async {
      when(() => dio.get<List<dynamic>>('/workspace/members')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            memberJson(),
            memberJson(
              id: 'm2',
              userId: 'u2',
              email: 'b@x.com',
              emailVerified: false,
              role: 'WORKER',
            ),
          ],
        ),
      );

      final list = await ds.list();

      expect(list, hasLength(2));
      expect(list[0].id, 'm1');
      expect(list[0].userId, 'u1');
      expect(list[0].email, 'a@x.com');
      expect(list[0].emailVerified, isTrue);
      expect(list[0].role, 'OWNER');
      expect(list[1].id, 'm2');
      expect(list[1].email, 'b@x.com');
      expect(list[1].emailVerified, isFalse);
      expect(list[1].role, 'WORKER');
    });

    test('200 con [] → List<Member> vacía', () async {
      when(
        () => dio.get<List<dynamic>>('/workspace/members'),
      ).thenAnswer((_) async => resp(200, body: <dynamic>[]));

      final list = await ds.list();

      expect(list, isEmpty);
    });

    test('timeout → MembersTimeoutFailure', () async {
      when(() => dio.get<List<dynamic>>('/workspace/members')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/workspace/members'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(ds.list(), throwsA(isA<MembersTimeoutFailure>()));
    });

    test('sin conexión → MembersNetworkFailure', () async {
      when(() => dio.get<List<dynamic>>('/workspace/members')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/workspace/members'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(ds.list(), throwsA(isA<MembersNetworkFailure>()));
    });

    test('403 → MembersForbiddenFailure', () async {
      // El subárbol /workspace exige ADMIN+ (RequireRole). Un rol por debajo
      // recibe 403; el datasource lo tipa explícito en vez de esconderlo.
      when(
        () => dio.get<List<dynamic>>('/workspace/members'),
      ).thenThrow(badResponse(403));

      await expectLater(ds.list(), throwsA(isA<MembersForbiddenFailure>()));
    });

    test('409 → MembersNoActiveOrgFailure', () async {
      // El guard RequireActiveOrg responde 409 si el caller no tiene org
      // activa. En la app el router desvía ese caso a /select-org antes de
      // montar la página, pero el contrato se mapea igual.
      when(
        () => dio.get<List<dynamic>>('/workspace/members'),
      ).thenThrow(badResponse(409));

      await expectLater(ds.list(), throwsA(isA<MembersNoActiveOrgFailure>()));
    });

    test('500 → MembersServerFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/workspace/members'),
      ).thenThrow(badResponse(500));

      await expectLater(ds.list(), throwsA(isA<MembersServerFailure>()));
    });

    test('body nulo → UnknownMembersFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/workspace/members'),
      ).thenAnswer((_) async => resp(200, body: null));

      await expectLater(ds.list(), throwsA(isA<UnknownMembersFailure>()));
    });

    test('body malformado (clave faltante) → UnknownMembersFailure', () async {
      // Sin email -> MemberResp.fromJson lanza FormatException, el datasource
      // lo colapsa a Unknown.
      when(() => dio.get<List<dynamic>>('/workspace/members')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            <String, dynamic>{'id': 'm1', 'user_id': 'u1', 'role': 'OWNER'},
          ],
        ),
      );

      await expectLater(ds.list(), throwsA(isA<UnknownMembersFailure>()));
    });
  });
}
