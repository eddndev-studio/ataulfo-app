import 'package:ataulfo/features/conversations/data/datasources/conversations_datasource.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioConversationsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioConversationsDatasource(dio);
  });

  Response<List<dynamic>> resp(int status, {List<dynamic>? body}) =>
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/sessions/b1'),
        statusCode: status,
        data: body,
      );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/sessions/b1'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/sessions/b1'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> convoJson({
    String chatLid = 'lid-1',
    String kind = 'DM',
    String? phone = '5215550001',
    String? displayName,
    bool isArchived = false,
    bool isPinned = false,
    bool isMarkedUnread = false,
    String? mutedUntil,
    int unreadCount = 0,
    String? lastMessagePreview,
    String? lastMessageType,
    String? lastMessageDirection,
    int? lastMessageTimestampMs,
  }) => <String, dynamic>{
    'chat_lid': chatLid,
    'kind': kind,
    'phone': ?phone,
    'display_name': ?displayName,
    'is_archived': isArchived,
    'is_pinned': isPinned,
    'is_marked_unread': isMarkedUnread,
    'muted_until': ?mutedUntil,
    'unread_count': unreadCount,
    'last_message_preview': ?lastMessagePreview,
    'last_message_type': ?lastMessageType,
    'last_message_direction': ?lastMessageDirection,
    'last_message_timestamp_ms': ?lastMessageTimestampMs,
  };

  group('DioConversationsDatasource.listForBot', () {
    test('200 con [DM, GROUP] → List<Conversation>', () async {
      when(() => dio.get<List<dynamic>>('/sessions/b1')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            convoJson(
              chatLid: 'lid-dm',
              displayName: 'Alice',
              isArchived: true,
              mutedUntil: '2026-06-01T12:00:00Z',
              unreadCount: 2,
              lastMessagePreview: 'nos vemos',
              lastMessageType: 'text',
              lastMessageDirection: 'INBOUND',
              lastMessageTimestampMs: 1700000000000,
            ),
            convoJson(
              chatLid: 'lid-grp',
              kind: 'GROUP',
              phone: null,
              isPinned: true,
            ),
          ],
        ),
      );

      final convos = await ds.listForBot('b1');

      expect(convos, hasLength(2));
      expect(convos[0].chatLid, 'lid-dm');
      expect(convos[0].kind, ConversationKind.dm);
      expect(convos[0].isArchived, isTrue);
      expect(convos[0].mutedUntil, DateTime.utc(2026, 6, 1, 12));
      // Actividad de bandeja end-to-end (wire → entidad).
      expect(convos[0].displayName, 'Alice');
      expect(convos[0].unreadCount, 2);
      expect(convos[0].lastMessagePreview, 'nos vemos');
      expect(convos[0].lastMessageTimestampMs, 1700000000000);
      expect(convos[1].kind, ConversationKind.group);
      expect(convos[1].phone, isNull);
      expect(convos[1].isPinned, isTrue);
      expect(convos[1].unreadCount, 0);
      expect(convos[1].lastMessagePreview, isNull);
      verify(() => dio.get<List<dynamic>>('/sessions/b1')).called(1);
    });

    test('200 con [] → lista vacía', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenAnswer((_) async => resp(200, body: <dynamic>[]));

      expect(await ds.listForBot('b1'), isEmpty);
    });

    test('timeout → ConversationsTimeoutFailure', () async {
      when(() => dio.get<List<dynamic>>('/sessions/b1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/sessions/b1'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<ConversationsTimeoutFailure>()),
      );
    });

    test('sin conexión → ConversationsNetworkFailure', () async {
      when(() => dio.get<List<dynamic>>('/sessions/b1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/sessions/b1'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<ConversationsNetworkFailure>()),
      );
    });

    test('403 → ConversationsForbiddenFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenThrow(badResponse(403));
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<ConversationsForbiddenFailure>()),
      );
    });

    test(
      '404 (bot ajeno/inexistente) → ConversationsNotFoundFailure',
      () async {
        when(
          () => dio.get<List<dynamic>>('/sessions/b1'),
        ).thenThrow(badResponse(404));
        await expectLater(
          ds.listForBot('b1'),
          throwsA(isA<ConversationsNotFoundFailure>()),
        );
      },
    );

    test('500 → ConversationsServerFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenThrow(badResponse(500));
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<ConversationsServerFailure>()),
      );
    });

    test('503 → ConversationsServerFailure (5xx genérico)', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenThrow(badResponse(503));
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<ConversationsServerFailure>()),
      );
    });

    test('409 (sin org activa, raro) → UnknownConversationsFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenThrow(badResponse(409));
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<UnknownConversationsFailure>()),
      );
    });

    test('418 (no contemplado) → UnknownConversationsFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenThrow(badResponse(418));
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<UnknownConversationsFailure>()),
      );
    });

    test('body nulo → UnknownConversationsFailure (contrato roto)', () async {
      when(
        () => dio.get<List<dynamic>>('/sessions/b1'),
      ).thenAnswer((_) async => resp(200));
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<UnknownConversationsFailure>()),
      );
    });

    test('elemento malformado → UnknownConversationsFailure', () async {
      when(() => dio.get<List<dynamic>>('/sessions/b1')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            <String, dynamic>{'chat_lid': 'x'}, // faltan claves
          ],
        ),
      );
      await expectLater(
        ds.listForBot('b1'),
        throwsA(isA<UnknownConversationsFailure>()),
      );
    });
  });
}
