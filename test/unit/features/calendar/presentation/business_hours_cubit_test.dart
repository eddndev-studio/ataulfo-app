import 'package:ataulfo/features/calendar/domain/entities/business_hours.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/business_hours_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CalendarRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const <BusinessHoursSlot>[]);
  });

  late _MockRepo repo;
  late BusinessHoursCubit cubit;

  setUp(() {
    repo = _MockRepo();
    cubit = BusinessHoursCubit(repo);
  });

  test('load ⇒ working y baseline iguales, sin cambios pendientes', () async {
    const slot = BusinessHoursSlot(weekday: 1, openMin: 540, closeMin: 1080);
    when(
      repo.getHours,
    ).thenAnswer((_) async => const <BusinessHoursSlot>[slot]);

    await cubit.load();

    expect(cubit.state.status, BusinessHoursStatus.loaded);
    expect(cubit.state.working, const <BusinessHoursSlot>[slot]);
    expect(cubit.state.dirty, isFalse);
    expect(cubit.state.canSave, isFalse);
  });

  test('addSlot agrega tramo por defecto y marca dirty', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    await cubit.load();

    cubit.addSlot(2);

    final day2 = cubit.state.slotsFor(2);
    expect(day2, hasLength(1));
    expect(day2.single.openMin, 540); // 09:00
    expect(day2.single.closeMin, 1020); // 17:00
    expect(cubit.state.dirty, isTrue);
  });

  test('updateSlotAt cambia apertura/cierre del tramo indicado', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    await cubit.load();
    cubit.addSlot(1);

    cubit.updateSlotAt(1, 0, openMin: 600, closeMin: 900);

    expect(cubit.state.slotsFor(1).single.openMin, 600);
    expect(cubit.state.slotsFor(1).single.closeMin, 900);
  });

  test('removeSlotAt quita el tramo por índice-en-día', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    await cubit.load();
    cubit.addSlot(1);
    cubit.addSlot(1);
    cubit.updateSlotAt(1, 1, openMin: 660, closeMin: 720);

    cubit.removeSlotAt(1, 0);

    expect(cubit.state.slotsFor(1), hasLength(1));
    expect(cubit.state.slotsFor(1).single.openMin, 660);
  });

  test('copyDay replica los tramos del origen en los destinos', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    await cubit.load();
    cubit.addSlot(1); // lunes 09:00-17:00

    cubit.copyDay(1, <int>{2, 3, 1}); // el propio origen se ignora

    expect(cubit.state.slotsFor(2), hasLength(1));
    expect(cubit.state.slotsFor(3).single.openMin, 540);
    expect(cubit.state.slotsFor(1), hasLength(1)); // no se duplicó a sí mismo
  });

  test('isValid detecta apertura>=cierre y cruces del mismo día', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    await cubit.load();

    cubit.addSlot(1);
    cubit.updateSlotAt(1, 0, openMin: 800, closeMin: 700); // invertido
    expect(cubit.state.isValid, isFalse);

    cubit.updateSlotAt(1, 0, openMin: 540, closeMin: 720);
    cubit.addSlot(1);
    cubit.updateSlotAt(1, 1, openMin: 660, closeMin: 900); // cruza con el 1º
    expect(cubit.state.isValid, isFalse);
    expect(cubit.state.canSave, isFalse);
  });

  test('save ok ⇒ PUT working y baseline se actualiza (dirty=false)', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    when(() => repo.putHours(any())).thenAnswer((_) async {});
    await cubit.load();
    cubit.addSlot(1);

    final f = await cubit.save();

    expect(f, isNull);
    expect(cubit.state.dirty, isFalse);
    verify(() => repo.putHours(cubit.state.working)).called(1);
  });

  test('clearDay quita todos los tramos del día y deja los demás', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    await cubit.load();
    cubit.addSlot(1);
    cubit.addSlot(1);
    cubit.addSlot(2);

    cubit.clearDay(1);

    expect(cubit.state.slotsFor(1), isEmpty);
    expect(cubit.state.slotsFor(2), hasLength(1));
    expect(cubit.state.dirty, isTrue);
  });

  test('save con 422 ⇒ devuelve Validation y conserva dirty', () async {
    when(repo.getHours).thenAnswer((_) async => const <BusinessHoursSlot>[]);
    when(
      () => repo.putHours(any()),
    ).thenThrow(const CalendarValidationFailure('tramos cruzados'));
    await cubit.load();
    cubit.addSlot(1);

    final f = await cubit.save();

    expect(f, isA<CalendarValidationFailure>());
    expect(cubit.state.dirty, isTrue);
    expect(cubit.state.saving, isFalse);
  });
}
