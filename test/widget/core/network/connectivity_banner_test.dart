import 'dart:async';

import 'package:ataulfo/core/network/connectivity_banner.dart';
import 'package:ataulfo/core/network/connectivity_cubit.dart';
import 'package:ataulfo/core/network/connectivity_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonitor implements ConnectivityMonitor {
  _FakeMonitor(this.online);
  final ctrl = StreamController<bool>.broadcast();
  bool online;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => ctrl.stream;

  Future<void> dispose() => ctrl.close();
}

const _offlineKey = Key('connectivity_banner.offline');

Widget _host(ConnectivityCubit cubit) => MaterialApp(
  home: BlocProvider<ConnectivityCubit>.value(
    value: cubit,
    child: const ConnectivityBanner(
      child: Scaffold(body: Center(child: Text('contenido'))),
    ),
  ),
);

void main() {
  late _FakeMonitor monitor;
  late ConnectivityCubit cubit;

  void make(bool online) {
    monitor = _FakeMonitor(online);
    cubit = ConnectivityCubit(monitor);
    addTearDown(cubit.close);
    addTearDown(monitor.dispose);
  }

  testWidgets('online: no muestra la barra (sí el contenido)', (tester) async {
    make(true);

    await tester.pumpWidget(_host(cubit));
    await tester.pump(); // _init() confirma online
    await tester.pumpAndSettle();

    expect(find.byKey(_offlineKey), findsNothing);
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('offline: muestra la barra (sin tapar el contenido)', (
    tester,
  ) async {
    make(false);

    await tester.pumpWidget(_host(cubit));
    await tester.pump(); // _init() corrige a offline
    await tester.pumpAndSettle();

    expect(find.byKey(_offlineKey), findsOneWidget);
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('al reconectar oculta la barra', (tester) async {
    make(false);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(_offlineKey), findsOneWidget);

    monitor.ctrl.add(true); // vuelve la red
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(_offlineKey), findsNothing);
  });
}
