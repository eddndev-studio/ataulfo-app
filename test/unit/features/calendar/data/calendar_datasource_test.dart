import 'package:ataulfo/features/calendar/data/datasources/calendar_datasource.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/entities/business_hours.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioCalendarDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioCalendarDatasource(dio);
  });

  Response<T> resp<T>(int status, {T? body, String path = '/x'}) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {dynamic data}) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );

  DioException byType(DioExceptionType type) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
  );

  // Stubs de verbo tipados (mocktail exige el mismo genérico que la llamada).
  void whenGet(Map<String, dynamic>? data, {int status = 200}) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => resp<Map<String, dynamic>>(status, body: data));
  }

  group('listEventTypes', () {
    test('200 ⇒ tipos mapeados', () async {
      whenGet(<String, dynamic>{
        'eventTypes': <dynamic>[
          <String, dynamic>{
            'id': 'et1',
            'name': 'Consulta',
            'description': 'd',
            'durationMin': 30,
            'active': true,
          },
        ],
      });
      final list = await ds.listEventTypes();
      expect(list, hasLength(1));
      expect(list.first.name, 'Consulta');
      expect(list.first.durationMin, 30);
    });

    test('403 ⇒ CalendarForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(badResponse(403));
      await expectLater(
        ds.listEventTypes(),
        throwsA(isA<CalendarForbiddenFailure>()),
      );
    });

    test('body malformado ⇒ UnknownCalendarFailure', () async {
      whenGet(<String, dynamic>{
        'eventTypes': <dynamic>[
          <String, dynamic>{'id': 'et1'},
        ],
      });
      await expectLater(
        ds.listEventTypes(),
        throwsA(isA<UnknownCalendarFailure>()),
      );
    });
  });

  group('createEventType', () {
    test('201 ⇒ id', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => resp<Map<String, dynamic>>(
          201,
          body: <String, dynamic>{'id': 'et9'},
        ),
      );
      final id = await ds.createEventType(
        name: 'X',
        description: '',
        durationMin: 45,
      );
      expect(id, 'et9');
    });

    test('422 con código desconocido ⇒ Validation SIN mensaje (jamás muestra '
        'el código wire crudo)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        badResponse(422, data: <String, dynamic>{'error': 'algo_nuevo'}),
      );
      await expectLater(
        ds.createEventType(name: 'X', description: '', durationMin: 7),
        throwsA(
          isA<CalendarValidationFailure>().having(
            (f) => f.message,
            'message',
            isNull,
          ),
        ),
      );
    });
  });

  group('updateEventType', () {
    test('204 ⇒ sin error; PUT al path con id', () async {
      when(
        () => dio.put<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => resp<dynamic>(204));
      await ds.updateEventType(
        id: 'et1',
        name: 'X',
        description: '',
        durationMin: 30,
        active: false,
      );
      final captured = verify(
        () => dio.put<dynamic>(captureAny(), data: captureAny(named: 'data')),
      ).captured;
      expect(captured[0], '/workspace/calendar/event-types/et1');
      expect((captured[1] as Map)['active'], false);
    });
  });

  group('getHours / putHours', () {
    test('getHours 200 ⇒ tramos mapeados', () async {
      whenGet(<String, dynamic>{
        'hours': <dynamic>[
          <String, dynamic>{'weekday': 1, 'openMin': 540, 'closeMin': 1080},
        ],
      });
      final hours = await ds.getHours();
      expect(hours.single.weekday, 1);
      expect(hours.single.openMin, 540);
    });

    test('putHours envía {hours:[...]} y 422 hours_overlap ⇒ Validation con '
        'copy traducido', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data'))).thenThrow(
        badResponse(422, data: <String, dynamic>{'error': 'hours_overlap'}),
      );
      await expectLater(
        ds.putHours(const <BusinessHoursSlot>[
          BusinessHoursSlot(weekday: 1, openMin: 540, closeMin: 1080),
        ]),
        throwsA(
          isA<CalendarValidationFailure>().having(
            (f) => f.message,
            'message',
            'Hay tramos de horario que se cruzan. Revísalos.',
          ),
        ),
      );
    });

    test('putHours 204 ⇒ serializa la semana como lista de tramos', () async {
      when(
        () => dio.put<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => resp<dynamic>(204));
      await ds.putHours(const <BusinessHoursSlot>[
        BusinessHoursSlot(weekday: 0, openMin: 600, closeMin: 720),
      ]);
      final data =
          verify(
                () => dio.put<dynamic>(any(), data: captureAny(named: 'data')),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['hours'], <dynamic>[
        <String, dynamic>{'weekday': 0, 'openMin': 600, 'closeMin': 720},
      ]);
    });
  });

  group('availability', () {
    test('parsea slots y envía eventTypeId + date=YYYY-MM-DD local', () async {
      whenGet(<String, dynamic>{
        'slots': <dynamic>['2026-07-05T15:00:00Z', '2026-07-05T15:30:00Z'],
      });
      final slots = await ds.availability(
        eventTypeId: 'et1',
        date: DateTime(2026, 7, 5, 9, 30),
      );
      expect(slots, hasLength(2));
      expect(slots.first.isUtc, isTrue);
      final query =
          verify(
                () => dio.get<Map<String, dynamic>>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(query['eventTypeId'], 'et1');
      expect(query['date'], '2026-07-05');
    });

    test('422 too_far_ahead ⇒ Validation con copy es-MX (la lectura valida la '
        'fecha pedida)', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        badResponse(422, data: <String, dynamic>{'error': 'too_far_ahead'}),
      );
      await expectLater(
        ds.availability(eventTypeId: 'et1', date: DateTime(2027, 1, 1)),
        throwsA(
          isA<CalendarValidationFailure>().having(
            (f) => f.message,
            'message',
            'La fecha es demasiado lejana. Elige una más cercana.',
          ),
        ),
      );
    });

    test('500 ⇒ CalendarServerFailure (la falla transitoria sigue siendo '
        'genérica)', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(badResponse(500));
      await expectLater(
        ds.availability(eventTypeId: 'et1', date: DateTime(2026, 7, 5)),
        throwsA(isA<CalendarServerFailure>()),
      );
    });
  });

  group('appointments', () {
    Map<String, dynamic> apptBody() => <String, dynamic>{
      'appointments': <dynamic>[
        <String, dynamic>{
          'id': 'a1',
          'eventTypeId': 'et1',
          'eventTypeName': 'Consulta',
          'botId': null,
          'chatLid': null,
          'customerName': 'Ana',
          'note': '',
          'startAt': '2026-07-15T16:00:00Z',
          'endAt': '2026-07-15T16:30:00Z',
          'status': 'CONFIRMED',
          'createdBy': 'OPERATOR',
        },
      ],
    };

    test('rango from/to ⇒ citas parseadas, query en UTC ISO', () async {
      whenGet(apptBody());
      final list = await ds.appointments(
        from: DateTime.utc(2026, 7, 15),
        to: DateTime.utc(2026, 7, 16),
      );
      expect(list.single.customerName, 'Ana');
      final query =
          verify(
                () => dio.get<Map<String, dynamic>>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(query['from'], contains('2026-07-15'));
      expect(query['to'], contains('2026-07-16'));
    });

    test('appointmentsByChat ⇒ query botId+chatLid', () async {
      whenGet(apptBody());
      await ds.appointmentsByChat(botId: 'b1', chatLid: 'c1');
      final query =
          verify(
                () => dio.get<Map<String, dynamic>>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(query['botId'], 'b1');
      expect(query['chatLid'], 'c1');
    });
  });

  group('createAppointment', () {
    void whenPost({
      int status = 201,
      Map<String, dynamic>? body,
      DioException? err,
    }) {
      final stub = when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
      if (err != null) {
        stub.thenThrow(err);
      } else {
        stub.thenAnswer(
          (_) async => resp<Map<String, dynamic>>(status, body: body),
        );
      }
    }

    test('201 ⇒ id; envía start en UTC ISO', () async {
      whenPost(body: <String, dynamic>{'id': 'a9'});
      final id = await ds.createAppointment(
        eventTypeId: 'et1',
        start: DateTime.utc(2026, 7, 15, 16, 0),
        customerName: 'Ana',
        note: 'nota',
      );
      expect(id, 'a9');
      final data =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  any(),
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['start'], contains('2026-07-15T16:00:00'));
      expect(data['customerName'], 'Ana');
    });

    test('409 ⇒ CalendarConflictFailure', () async {
      whenPost(err: badResponse(409));
      await expectLater(
        ds.createAppointment(
          eventTypeId: 'et1',
          start: DateTime.utc(2026, 7, 15, 16, 0),
          customerName: 'Ana',
          note: '',
        ),
        throwsA(isA<CalendarConflictFailure>()),
      );
    });

    test(
      '422 con código de reserva conocido ⇒ Validation con copy es-MX',
      () async {
        const cases = <String, String>{
          'past': 'Esa fecha ya pasó. Elige una futura.',
          'too_far_ahead':
              'La fecha es demasiado lejana. Elige una más cercana.',
          'outside_business_hours':
              'La hora elegida cae fuera del horario de atención.',
          'unaligned': 'La hora debe caer en bloques de 15 minutos.',
          'event_type_inactive': 'Ese tipo de cita está desactivado.',
          'invalid_appointment': 'Los datos de la cita no son válidos.',
        };
        for (final entry in cases.entries) {
          whenPost(
            err: badResponse(422, data: <String, dynamic>{'error': entry.key}),
          );
          await expectLater(
            ds.createAppointment(
              eventTypeId: 'et1',
              start: DateTime.utc(2020, 1, 1),
              customerName: 'Ana',
              note: '',
            ),
            throwsA(
              isA<CalendarValidationFailure>().having(
                (f) => f.message,
                'message',
                entry.value,
              ),
            ),
            reason: 'código ${entry.key}',
          );
        }
      },
    );
  });

  group('setAppointmentStatus', () {
    test('envía el status de wire correcto', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => resp<dynamic>(204));
      await ds.setAppointmentStatus(id: 'a1', status: AppointmentStatus.noShow);
      final captured = verify(
        () => dio.post<dynamic>(captureAny(), data: captureAny(named: 'data')),
      ).captured;
      expect(captured[0], '/workspace/calendar/appointments/a1/status');
      expect((captured[1] as Map)['status'], 'NO_SHOW');
    });

    test('404 ⇒ CalendarNotFoundFailure', () async {
      when(
        () => dio.post<dynamic>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(404));
      await expectLater(
        ds.setAppointmentStatus(id: 'x', status: AppointmentStatus.completed),
        throwsA(isA<CalendarNotFoundFailure>()),
      );
    });
  });

  group('mapeo genérico de DioException (vía listEventTypes)', () {
    void whenGetThrows(DioException e) {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(e);
    }

    test('timeouts ⇒ CalendarTimeoutFailure', () async {
      for (final t in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        whenGetThrows(byType(t));
        await expectLater(
          ds.listEventTypes(),
          throwsA(isA<CalendarTimeoutFailure>()),
        );
      }
    });

    test('connectionError ⇒ CalendarNetworkFailure', () async {
      whenGetThrows(byType(DioExceptionType.connectionError));
      await expectLater(
        ds.listEventTypes(),
        throwsA(isA<CalendarNetworkFailure>()),
      );
    });

    test('500 ⇒ CalendarServerFailure', () async {
      whenGetThrows(badResponse(500));
      await expectLater(
        ds.listEventTypes(),
        throwsA(isA<CalendarServerFailure>()),
      );
    });

    test('418 (no contemplado) ⇒ UnknownCalendarFailure', () async {
      whenGetThrows(badResponse(418));
      await expectLater(
        ds.listEventTypes(),
        throwsA(isA<UnknownCalendarFailure>()),
      );
    });
  });
}
