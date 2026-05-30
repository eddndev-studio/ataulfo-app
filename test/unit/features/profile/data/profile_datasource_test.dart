import 'package:ataulfo/features/profile/data/datasources/profile_datasource.dart';
import 'package:ataulfo/features/profile/domain/failures/profile_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioProfileDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioProfileDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/p'),
    statusCode: status,
    data: body,
  );

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/p'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/p'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> profileJson() => <String, dynamic>{
    'chat_lid': 'lid-dm',
    'kind': 'DM',
    'phone': '521555',
    'display_name': 'Alice',
    'photo_url': 'https://cdn/p.jpg',
    'is_archived': false,
    'is_pinned': false,
    'is_marked_unread': false,
  };

  group('DioProfileDatasource.fetch', () {
    test(
      '200 → ChatProfile; el chatLid se percent-encodea en el path',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(any()),
        ).thenAnswer((_) async => resp(200, body: profileJson()));

        final p = await ds.fetch('b1', 'grp@g.us');
        expect(p.chatLid, 'lid-dm');
        expect(p.displayName, 'Alice');
        expect(p.photoUrl, 'https://cdn/p.jpg');
        verify(
          () =>
              dio.get<Map<String, dynamic>>('/sessions/b1/grp%40g.us/profile'),
        ).called(1);
      },
    );

    test('body nulo → UnknownProfileFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => resp(200));
      await expectLater(
        ds.fetch('b1', 'x'),
        throwsA(isA<UnknownProfileFailure>()),
      );
    });

    test('timeout → ProfileTimeoutFailure', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/p'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        ds.fetch('b1', 'x'),
        throwsA(isA<ProfileTimeoutFailure>()),
      );
    });

    test('sin conexión → ProfileNetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/p'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        ds.fetch('b1', 'x'),
        throwsA(isA<ProfileNetworkFailure>()),
      );
    });

    test(
      '403 → Forbidden, 404 → NotFound, 500 → Server, 418 → Unknown',
      () async {
        when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(bad(403));
        await expectLater(
          ds.fetch('b1', 'x'),
          throwsA(isA<ProfileForbiddenFailure>()),
        );
        when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(bad(404));
        await expectLater(
          ds.fetch('b1', 'x'),
          throwsA(isA<ProfileNotFoundFailure>()),
        );
        when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(bad(500));
        await expectLater(
          ds.fetch('b1', 'x'),
          throwsA(isA<ProfileServerFailure>()),
        );
        when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(bad(418));
        await expectLater(
          ds.fetch('b1', 'x'),
          throwsA(isA<UnknownProfileFailure>()),
        );
      },
    );

    test('body malformado → UnknownProfileFailure', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => resp(200, body: <String, dynamic>{'chat_lid': 'x'}),
      );
      await expectLater(
        ds.fetch('b1', 'x'),
        throwsA(isA<UnknownProfileFailure>()),
      );
    });
  });
}
