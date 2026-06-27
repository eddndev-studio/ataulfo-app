import 'dart:async';

import 'package:ataulfo/core/network/connectivity_cubit.dart';
import 'package:ataulfo/core/network/connectivity_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonitor implements ConnectivityMonitor {
  _FakeMonitor(this.initial);

  final bool initial;
  final StreamController<bool> _ctrl = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => initial;

  @override
  Stream<bool> get onlineChanges => _ctrl.stream;

  void push(bool v) => _ctrl.add(v);
  Future<void> dispose() => _ctrl.close();
}

void main() {
  test(
    'arranca optimista en true y se corrige con el primer chequeo',
    () async {
      final monitor = _FakeMonitor(false);
      final cubit = ConnectivityCubit(monitor);

      expect(cubit.state, isTrue); // optimista, antes del chequeo
      await Future<void>.delayed(Duration.zero); // deja correr _init()
      expect(cubit.state, isFalse);

      await cubit.close();
      await monitor.dispose();
    },
  );

  test('emite cambios del stream sin re-emitir el mismo valor', () async {
    final monitor = _FakeMonitor(true);
    final cubit = ConnectivityCubit(monitor);
    final seen = <bool>[];
    final sub = cubit.stream.listen(seen.add);

    await Future<void>.delayed(Duration.zero); // _init: true == state, no emite
    monitor.push(false);
    monitor.push(false); // duplicado: no re-emite
    monitor.push(true);
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    await cubit.close();
    await monitor.dispose();
    expect(seen, <bool>[false, true]);
  });

  test('no emite tras close (guard isClosed)', () async {
    final monitor = _FakeMonitor(true);
    final cubit = ConnectivityCubit(monitor);
    await cubit.close();

    monitor.push(false); // tras close: ni crash ni emisión
    await Future<void>.delayed(Duration.zero);

    expect(cubit.isClosed, isTrue);
    await monitor.dispose();
  });
}
