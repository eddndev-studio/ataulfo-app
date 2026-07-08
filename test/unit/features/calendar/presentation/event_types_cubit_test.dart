import 'package:ataulfo/features/calendar/domain/entities/event_type.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/event_types_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CalendarRepository {}

const _et = EventType(
  id: 'et1',
  name: 'Consulta',
  description: '',
  durationMin: 30,
  active: true,
);

void main() {
  blocTest<EventTypesCubit, EventTypesState>(
    'load ok ⇒ [loading, loaded(items)]',
    build: () {
      final repo = _MockRepo();
      when(repo.listEventTypes).thenAnswer((_) async => <EventType>[_et]);
      return EventTypesCubit(repo);
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<EventTypesState>().having(
        (s) => s.status,
        's',
        EventTypesStatus.loading,
      ),
      isA<EventTypesState>()
          .having((s) => s.status, 's', EventTypesStatus.loaded)
          .having((s) => s.items, 'items', <EventType>[_et]),
    ],
  );

  blocTest<EventTypesCubit, EventTypesState>(
    'load forbidden ⇒ error',
    build: () {
      final repo = _MockRepo();
      when(repo.listEventTypes).thenThrow(const CalendarForbiddenFailure());
      return EventTypesCubit(repo);
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<EventTypesState>().having(
        (s) => s.status,
        's',
        EventTypesStatus.loading,
      ),
      isA<EventTypesState>().having(
        (s) => s.status,
        's',
        EventTypesStatus.error,
      ),
    ],
  );

  blocTest<EventTypesCubit, EventTypesState>(
    'create ok ⇒ recarga la lista y devuelve null',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.createEventType(
          name: any(named: 'name'),
          description: any(named: 'description'),
          durationMin: any(named: 'durationMin'),
        ),
      ).thenAnswer((_) async => 'et2');
      when(repo.listEventTypes).thenAnswer((_) async => <EventType>[_et]);
      return EventTypesCubit(repo);
    },
    act: (c) async {
      final f = await c.create(name: 'X', description: '', durationMin: 45);
      expect(f, isNull);
    },
    verify: (c) {
      expect(c.state.items, <EventType>[_et]);
      expect(c.state.mutating, isFalse);
    },
  );

  blocTest<EventTypesCubit, EventTypesState>(
    'create con 422 ⇒ devuelve la Validation y no recarga',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.createEventType(
          name: any(named: 'name'),
          description: any(named: 'description'),
          durationMin: any(named: 'durationMin'),
        ),
      ).thenThrow(const CalendarValidationFailure('duración inválida'));
      return EventTypesCubit(repo);
    },
    act: (c) async {
      final f = await c.create(name: 'X', description: '', durationMin: 7);
      expect(
        f,
        isA<CalendarValidationFailure>().having(
          (e) => e.message,
          'm',
          'duración inválida',
        ),
      );
    },
    // El mock de listEventTypes NO se stubbeó: si el cubit intentara recargar
    // tras el 422, la llamada no-stubbeada rompería el test. Que pase prueba
    // que no recarga.
    verify: (c) {
      expect(c.state.mutating, isFalse);
    },
  );
}
