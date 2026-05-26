import 'package:agentic/features/memberships/data/datasources/memberships_datasource.dart';
import 'package:agentic/features/memberships/domain/failures/memberships_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioMembershipsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioMembershipsDatasource(dio);
  });

  Response<List<dynamic>> resp(int status, {List<dynamic>? body}) =>
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/auth/memberships'),
        statusCode: status,
        data: body,
      );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/auth/memberships'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/auth/memberships'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> membershipJson({
    String orgId = 'o1',
    String orgName = 'Acme',
    String role = 'OWNER',
  }) => <String, dynamic>{
    'org_id': orgId,
    'org_name': orgName,
    'role': role,
  };

  group('DioMembershipsDatasource.list', () {
    test('200 con [membershipResp...] → List<Membership>', () async {
      when(() => dio.get<List<dynamic>>('/auth/memberships')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            membershipJson(),
            membershipJson(orgId: 'o2', orgName: 'Bravo', role: 'ADMIN'),
          ],
        ),
      );

      final list = await ds.list();

      expect(list, hasLength(2));
      expect(list[0].orgId, 'o1');
      expect(list[0].orgName, 'Acme');
      expect(list[0].role, 'OWNER');
      expect(list[1].orgId, 'o2');
      expect(list[1].orgName, 'Bravo');
      expect(list[1].role, 'ADMIN');
    });

    test('200 con [] → List<Membership> vacía (caller sin orgs)', () async {
      // El backend documenta 200 con [] como estado legítimo (caller perdió
      // memberships activas). El cliente NO lo traduce a NotFound.
      when(
        () => dio.get<List<dynamic>>('/auth/memberships'),
      ).thenAnswer((_) async => resp(200, body: <dynamic>[]));

      final list = await ds.list();

      expect(list, isEmpty);
    });

    test('timeout → MembershipsTimeoutFailure', () async {
      when(() => dio.get<List<dynamic>>('/auth/memberships')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/memberships'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.list(),
        throwsA(isA<MembershipsTimeoutFailure>()),
      );
    });

    test('sin conexión → MembershipsNetworkFailure', () async {
      when(() => dio.get<List<dynamic>>('/auth/memberships')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/memberships'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.list(),
        throwsA(isA<MembershipsNetworkFailure>()),
      );
    });

    test('403 → MembershipsForbiddenFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/auth/memberships'),
      ).thenThrow(badResponse(403));

      await expectLater(
        ds.list(),
        throwsA(isA<MembershipsForbiddenFailure>()),
      );
    });

    test('500 → MembershipsServerFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/auth/memberships'),
      ).thenThrow(badResponse(500));

      await expectLater(
        ds.list(),
        throwsA(isA<MembershipsServerFailure>()),
      );
    });

    test('body nulo → UnknownMembershipsFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/auth/memberships'),
      ).thenAnswer((_) async => resp(200, body: null));

      await expectLater(
        ds.list(),
        throwsA(isA<UnknownMembershipsFailure>()),
      );
    });

    test('body malformado (clave faltante) → UnknownMembershipsFailure', () async {
      // Sin org_name -> MembershipResp.fromJson lanza FormatException, el
      // datasource lo colapsa a Unknown.
      when(() => dio.get<List<dynamic>>('/auth/memberships')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            <String, dynamic>{'org_id': 'o1', 'role': 'OWNER'},
          ],
        ),
      );

      await expectLater(
        ds.list(),
        throwsA(isA<UnknownMembershipsFailure>()),
      );
    });
  });
}
