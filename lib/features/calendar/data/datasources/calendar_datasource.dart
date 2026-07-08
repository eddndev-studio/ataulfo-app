import 'package:dio/dio.dart';

import '../../domain/entities/appointment.dart';
import '../../domain/entities/business_hours.dart';
import '../../domain/entities/event_type.dart';
import '../../domain/failures/calendar_failure.dart';
import '../dto/appointment_dto.dart';
import '../dto/business_hours_dto.dart';
import '../dto/event_type_dto.dart';
import '../mappers/appointment_mapper.dart';
import '../mappers/business_hours_mapper.dart';
import '../mappers/event_type_mapper.dart';

/// Puerto de datos del calendario. Las implementaciones lanzan
/// `CalendarFailure` tipadas; nunca DioException cruda.
abstract interface class CalendarDatasource {
  Future<List<EventType>> listEventTypes();
  Future<String> createEventType({
    required String name,
    required String description,
    required int durationMin,
  });
  Future<void> updateEventType({
    required String id,
    required String name,
    required String description,
    required int durationMin,
    required bool active,
  });
  Future<List<BusinessHoursSlot>> getHours();
  Future<void> putHours(List<BusinessHoursSlot> hours);
  Future<List<DateTime>> availability({
    required String eventTypeId,
    required DateTime date,
  });
  Future<List<Appointment>> appointments({
    required DateTime from,
    required DateTime to,
  });
  Future<List<Appointment>> appointmentsByChat({
    required String botId,
    required String chatLid,
  });
  Future<String> createAppointment({
    required String eventTypeId,
    required DateTime start,
    required String customerName,
    required String note,
  });
  Future<void> setAppointmentStatus({
    required String id,
    required AppointmentStatus status,
  });
}

class DioCalendarDatasource implements CalendarDatasource {
  DioCalendarDatasource(this._dio);

  final Dio _dio;

  static const String _base = '/workspace/calendar';

  @override
  Future<List<EventType>> listEventTypes() => _guardRead(
    () async => _parseEventTypes(await _getMap('$_base/event-types')),
  );

  @override
  Future<String> createEventType({
    required String name,
    required String description,
    required int durationMin,
  }) => _guardMutation(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/event-types',
      data: <String, dynamic>{
        'name': name,
        'description': description,
        'durationMin': durationMin,
      },
    );
    return _extractId(res.data);
  });

  @override
  Future<void> updateEventType({
    required String id,
    required String name,
    required String description,
    required int durationMin,
    required bool active,
  }) => _guardMutation(() async {
    await _dio.put<dynamic>(
      '$_base/event-types/$id',
      data: <String, dynamic>{
        'name': name,
        'description': description,
        'durationMin': durationMin,
        'active': active,
      },
    );
  });

  @override
  Future<List<BusinessHoursSlot>> getHours() =>
      _guardRead(() async => _parseHours(await _getMap('$_base/hours')));

  @override
  Future<void> putHours(List<BusinessHoursSlot> hours) =>
      _guardMutation(() async {
        await _dio.put<dynamic>(
          '$_base/hours',
          data: <String, dynamic>{
            'hours': hours
                .map(BusinessHoursMapper.entityToDto)
                .map((d) => d.toJson())
                .toList(growable: false),
          },
        );
      });

  @override
  Future<List<DateTime>> availability({
    required String eventTypeId,
    required DateTime date,
  }) => _guardRead(() async {
    final body = await _getMap(
      '$_base/availability',
      query: <String, dynamic>{
        'eventTypeId': eventTypeId,
        'date': _localDate(date),
      },
    );
    return _parseSlots(body);
  });

  @override
  Future<List<Appointment>> appointments({
    required DateTime from,
    required DateTime to,
  }) => _guardRead(() async {
    final body = await _getMap(
      '$_base/appointments',
      query: <String, dynamic>{
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return _parseAppointments(body);
  });

  @override
  Future<List<Appointment>> appointmentsByChat({
    required String botId,
    required String chatLid,
  }) => _guardRead(() async {
    final body = await _getMap(
      '$_base/appointments',
      query: <String, dynamic>{'botId': botId, 'chatLid': chatLid},
    );
    return _parseAppointments(body);
  });

  @override
  Future<String> createAppointment({
    required String eventTypeId,
    required DateTime start,
    required String customerName,
    required String note,
  }) => _guardMutation(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/appointments',
      data: <String, dynamic>{
        'eventTypeId': eventTypeId,
        'start': start.toUtc().toIso8601String(),
        'customerName': customerName,
        'note': note,
      },
    );
    return _extractId(res.data);
  });

  @override
  Future<void> setAppointmentStatus({
    required String id,
    required AppointmentStatus status,
  }) => _guardMutation(() async {
    await _dio.post<dynamic>(
      '$_base/appointments/$id/status',
      data: <String, dynamic>{'status': AppointmentMapper.statusToWire(status)},
    );
  });

  // ── Helpers de red ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    final body = res.data;
    if (body == null) throw const FormatException('body nulo');
    return body;
  }

  String _extractId(Map<String, dynamic>? body) {
    final id = body?['id'];
    if (id is! String) throw const FormatException('respuesta sin id');
    return id;
  }

  /// `YYYY-MM-DD` del día LOCAL (la hora se descarta): es el día calendario que
  /// el operador eligió para pedir disponibilidad.
  String _localDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<EventType> _parseEventTypes(Map<String, dynamic> body) =>
      (body['eventTypes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(EventTypeDto.fromJson)
          .map(EventTypeMapper.dtoToEntity)
          .toList(growable: false);

  List<BusinessHoursSlot> _parseHours(Map<String, dynamic> body) =>
      (body['hours'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(BusinessHoursSlotDto.fromJson)
          .map(BusinessHoursMapper.dtoToEntity)
          .toList(growable: false);

  List<DateTime> _parseSlots(Map<String, dynamic> body) =>
      (body['slots'] as List<dynamic>)
          .cast<String>()
          .map((s) => DateTime.parse(s).toUtc())
          .toList(growable: false);

  List<Appointment> _parseAppointments(Map<String, dynamic> body) =>
      (body['appointments'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AppointmentDto.fromJson)
          .map(AppointmentMapper.dtoToEntity)
          .toList(growable: false);

  // ── Traducción de errores ───────────────────────────────────────────────

  /// Envuelve una lectura: DioException/parse rotos ⇒ CalendarFailure de
  /// lectura (sin 409/422 propios, que son de las mutaciones).
  Future<T> _guardRead<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on CalendarFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownCalendarFailure();
    } on TypeError {
      throw const UnknownCalendarFailure();
    }
  }

  /// Envuelve una mutación: añade 409 (hueco tomado / tramos cruzados) y 422
  /// (inválido, con mensaje del backend) sobre el mapeo de lectura.
  Future<T> _guardMutation<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on CalendarFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapMutationDioException(e);
    } on FormatException {
      throw const UnknownCalendarFailure();
    } on TypeError {
      throw const UnknownCalendarFailure();
    }
  }

  CalendarFailure _mapMutationDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse) {
      final status = e.response?.statusCode;
      if (status == 409) return const CalendarConflictFailure();
      if (status == 422) {
        return CalendarValidationFailure(_validationMessage(e.response?.data));
      }
    }
    return _mapDioException(e);
  }

  CalendarFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const CalendarTimeoutFailure();
      case DioExceptionType.connectionError:
        return const CalendarNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const CalendarForbiddenFailure();
        if (status == 404) return const CalendarNotFoundFailure();
        if (status >= 500 && status < 600) return const CalendarServerFailure();
        return const UnknownCalendarFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownCalendarFailure();
    }
  }

  /// Copy es-MX por código estable de rechazo 422 del backend
  /// (`{"error": code}`). El wire manda códigos, no frases: aquí es la única
  /// frontera que los conoce y los traduce. Un código fuera del mapa degrada a
  /// null (la UI cae a su copy genérico); JAMÁS se muestra el código crudo.
  static const Map<String, String> _validationCopy = <String, String>{
    'past': 'Esa fecha ya pasó. Elige una futura.',
    'too_far_ahead': 'La fecha es demasiado lejana. Elige una más cercana.',
    'outside_business_hours':
        'La hora elegida cae fuera del horario de atención.',
    'unaligned': 'La hora debe caer en bloques de 15 minutos.',
    'event_type_inactive': 'Ese tipo de cita está desactivado.',
    'invalid_appointment': 'Los datos de la cita no son válidos.',
    'hours_overlap': 'Hay tramos de horario que se cruzan. Revísalos.',
  };

  String? _validationMessage(dynamic data) {
    if (data is! Map) return null;
    final code = data['error'];
    if (code is! String) return null;
    return _validationCopy[code];
  }
}
