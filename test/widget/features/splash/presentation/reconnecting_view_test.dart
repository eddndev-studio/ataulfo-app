import 'dart:async';

import 'package:ataulfo/core/network/connectivity_cubit.dart';
import 'package:ataulfo/core/network/connectivity_monitor.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/splash/presentation/pages/reconnecting_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

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

void main() {
  late _MockRepo repo;
  late _FakeMonitor monitor;
  late ConnectivityCubit connectivity;
  late AuthBloc auth;

  void make(bool online) {
    repo = _MockRepo();
    when(repo.hasTokens).thenAnswer((_) async => true);
    // Sigue offline por defecto: la re-verificación vuelve a fallar por red.
    when(repo.me).thenThrow(const NetworkFailure());
    monitor = _FakeMonitor(online);
    connectivity = ConnectivityCubit(monitor);
    auth = AuthBloc(repo);
    addTearDown(connectivity.close);
    addTearDown(auth.close);
    addTearDown(monitor.dispose);
  }

  Widget host() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ConnectivityCubit>.value(value: connectivity),
        BlocProvider<AuthBloc>.value(value: auth),
      ],
      child: const ReconnectingView(),
    ),
  );

  testWidgets('muestra "Sin conexión" y un botón de reintentar', (
    tester,
  ) async {
    make(false);
    await tester.pumpWidget(host());
    await tester.pump(); // _init() del cubit corrige a offline

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('tocar "Reintentar" re-verifica la sesión (AuthCheckRequested)', (
    tester,
  ) async {
    make(false);
    await tester.pumpWidget(host());
    await tester.pump();

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    // _onCheck corrió ⇒ se despachó AuthCheckRequested.
    verify(() => repo.hasTokens()).called(1);
  });

  testWidgets('al volver la red (flanco offline→online) re-verifica sola', (
    tester,
  ) async {
    make(false);
    await tester.pumpWidget(host());
    await tester.pump(); // optimista true → _init() corrige a offline

    monitor.ctrl.add(true); // vuelve la red
    await tester.pump();

    verify(() => repo.hasTokens()).called(1);
  });

  testWidgets(
    'sondea periódicamente con el enlace ARRIBA pero el servidor inalcanzable '
    '(no hay flanco que escuchar)',
    (tester) async {
      // Enlace presente (online) pero me() falla por red: el flanco
      // offline→online nunca llega, así que la recuperación depende del sondeo.
      make(true);
      await tester.pumpWidget(host());
      await tester.pump(); // _init() confirma online (sin flanco)

      // Sin sondeo no se re-verificaría nunca; al cumplirse el intervalo, sí.
      await tester.pump(const Duration(seconds: 5));
      verify(() => repo.hasTokens()).called(1);

      await tester.pump(const Duration(seconds: 5));
      verify(() => repo.hasTokens()).called(1);
    },
  );

  testWidgets('una caída de red (online→offline) NO dispara re-verificación', (
    tester,
  ) async {
    make(true);
    await tester.pumpWidget(host());
    await tester.pump();

    monitor.ctrl.add(false); // se cae la red
    await tester.pump();

    verifyNever(() => repo.hasTokens());
  });
}
