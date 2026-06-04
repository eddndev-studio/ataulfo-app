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

  Response<void> voidResp(int status) => Response<void>(
    requestOptions: RequestOptions(path: '/workspace/members'),
    statusCode: status,
  );

  group('DioMembersDatasource.changeRole', () {
    test('204 → completa sin error y envía el rol en el body', () async {
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => voidResp(204));

      await ds.changeRole('m1', 'ADMIN');

      verify(
        () => dio.put<void>(
          '/workspace/members/m1/role',
          data: const <String, dynamic>{'role': 'ADMIN'},
        ),
      ).called(1);
    });

    test('403 → MembersSelfRoleUpgradeFailure', () async {
      // En change-role el único 403 del servicio es el self-upgrade.
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(403));

      await expectLater(
        ds.changeRole('m1', 'OWNER'),
        throwsA(isA<MembersSelfRoleUpgradeFailure>()),
      );
    });

    test('404 → MembersNotFoundFailure', () async {
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(404));

      await expectLater(
        ds.changeRole('m1', 'ADMIN'),
        throwsA(isA<MembersNotFoundFailure>()),
      );
    });

    test('409 → MembersSoleOwnerFailure', () async {
      // Degradar al único owner: el servicio responde 409 (no NoActiveOrg).
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(409));

      await expectLater(
        ds.changeRole('m1', 'ADMIN'),
        throwsA(isA<MembersSoleOwnerFailure>()),
      );
    });

    test('500 → MembersServerFailure', () async {
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(500));

      await expectLater(
        ds.changeRole('m1', 'ADMIN'),
        throwsA(isA<MembersServerFailure>()),
      );
    });

    test('sin conexión → MembersNetworkFailure', () async {
      when(() => dio.put<void>(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/workspace/members/m1/role'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.changeRole('m1', 'ADMIN'),
        throwsA(isA<MembersNetworkFailure>()),
      );
    });
  });

  group('DioMembersDatasource.removeMember', () {
    test('204 → completa sin error y pega al path del miembro', () async {
      when(
        () => dio.delete<void>(any()),
      ).thenAnswer((_) async => voidResp(204));

      await ds.removeMember('m1');

      verify(() => dio.delete<void>('/workspace/members/m1')).called(1);
    });

    test('404 → MembersNotFoundFailure', () async {
      when(() => dio.delete<void>(any())).thenThrow(badResponse(404));

      await expectLater(
        ds.removeMember('m1'),
        throwsA(isA<MembersNotFoundFailure>()),
      );
    });

    test('409 → MembersSoleOwnerFailure', () async {
      // Quitar al único owner deja la org sin dueño: 409.
      when(() => dio.delete<void>(any())).thenThrow(badResponse(409));

      await expectLater(
        ds.removeMember('m1'),
        throwsA(isA<MembersSoleOwnerFailure>()),
      );
    });

    test('403 → MembersForbiddenFailure (guard de ruta, defensivo)', () async {
      // RemoveMember no tiene 403 a nivel de servicio; un 403 sólo vendría del
      // guard de rol de la ruta. Se mapea al genérico, no a self-upgrade.
      when(() => dio.delete<void>(any())).thenThrow(badResponse(403));

      await expectLater(
        ds.removeMember('m1'),
        throwsA(isA<MembersForbiddenFailure>()),
      );
    });

    test('500 → MembersServerFailure', () async {
      when(() => dio.delete<void>(any())).thenThrow(badResponse(500));

      await expectLater(
        ds.removeMember('m1'),
        throwsA(isA<MembersServerFailure>()),
      );
    });
  });

  group('DioMembersDatasource.transferOwnership', () {
    test('204 → completa y envía {to_membership_id}', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => voidResp(204));

      await ds.transferOwnership('m2');

      verify(
        () => dio.post<void>(
          '/workspace/transfer-ownership',
          data: const <String, dynamic>{'to_membership_id': 'm2'},
        ),
      ).called(1);
    });

    test('403 (no OWNER real) → MembersForbiddenFailure', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(403));

      await expectLater(
        ds.transferOwnership('m2'),
        throwsA(isA<MembersForbiddenFailure>()),
      );
    });

    test('404 → MembersNotFoundFailure', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(404));

      await expectLater(
        ds.transferOwnership('m2'),
        throwsA(isA<MembersNotFoundFailure>()),
      );
    });

    test('422 (self-transfer, defensivo) → UnknownMembersFailure', () async {
      when(
        () => dio.post<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(422));

      await expectLater(
        ds.transferOwnership('m2'),
        throwsA(isA<UnknownMembersFailure>()),
      );
    });
  });

  group('DioMembersDatasource.assignedBots', () {
    Response<Map<String, dynamic>> objResp(int status, {Object? botIds}) =>
        Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/workspace/members/m1/bots'),
          statusCode: status,
          data: botIds == null ? null : <String, dynamic>{'bot_ids': botIds},
        );

    test('200 {bot_ids:[...]} → List<String>', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => objResp(200, botIds: <dynamic>['b1', 'b2']));

      final ids = await ds.assignedBots('m1');

      expect(ids, <String>['b1', 'b2']);
      verify(
        () => dio.get<Map<String, dynamic>>('/workspace/members/m1/bots'),
      ).called(1);
    });

    test('200 {bot_ids:[]} → vacía', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => objResp(200, botIds: <dynamic>[]));

      expect(await ds.assignedBots('m1'), isEmpty);
    });

    test('404 → MembersNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenThrow(badResponse(404));

      await expectLater(
        ds.assignedBots('m1'),
        throwsA(isA<MembersNotFoundFailure>()),
      );
    });

    test('body malformado → UnknownMembersFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => objResp(200));

      await expectLater(
        ds.assignedBots('m1'),
        throwsA(isA<UnknownMembersFailure>()),
      );
    });
  });

  group('DioMembersDatasource.assignBots', () {
    test('204 → completa y envía el set completo {bot_ids}', () async {
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => voidResp(204));

      await ds.assignBots('m1', <String>['b1', 'b3']);

      verify(
        () => dio.put<void>(
          '/workspace/members/m1/bots',
          data: const <String, dynamic>{
            'bot_ids': <String>['b1', 'b3'],
          },
        ),
      ).called(1);
    });

    test('lista vacía desasigna (envía bot_ids: [])', () async {
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => voidResp(204));

      await ds.assignBots('m1', const <String>[]);

      verify(
        () => dio.put<void>(
          '/workspace/members/m1/bots',
          data: const <String, dynamic>{'bot_ids': <String>[]},
        ),
      ).called(1);
    });

    test('404 → MembersNotFoundFailure', () async {
      when(
        () => dio.put<void>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(404));

      await expectLater(
        ds.assignBots('m1', const <String>['b1']),
        throwsA(isA<MembersNotFoundFailure>()),
      );
    });
  });
}
