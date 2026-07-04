import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:ataulfo/features/profile/presentation/widgets/chat_thread_app_bar.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _FakeMonitorDs implements MonitorActivityDatasource {
  @override
  Stream<MonitorEvent> activity(String botId, String chatLid) =>
      const Stream<MonitorEvent>.empty();
}

/// "Vaciar historial" en el menú "⋮" del hilo (S07 RF#10): entrada solo
/// ADMIN+ (destructiva), con confirmación explícita antes de despachar — un
/// tap accidental jamás borra nada.
void main() {
  late _MockProfileBloc profile;
  late _MockAuthBloc auth;
  late _MockMessagesBloc messages;

  setUpAll(() => registerFallbackValue(const MessagesClearHistoryRequested()));

  setUp(() {
    profile = _MockProfileBloc();
    when(() => profile.state).thenReturn(const ProfileInitial());
    auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(
      const AuthAuthenticated(
        Identity(userId: 'u1', email: 'x@x', orgId: 'o1', role: 'ADMIN'),
      ),
    );
    messages = _MockMessagesBloc();
    when(() => messages.state).thenReturn(const MessagesInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileBloc>.value(value: profile),
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<MessagesBloc>.value(value: messages),
        BlocProvider<MonitorLiveCubit>(
          create: (_) => MonitorLiveCubit(_FakeMonitorDs()),
        ),
      ],
      child: const Scaffold(
        appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
        body: SizedBox.shrink(),
      ),
    ),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('thread.more')));
    await tester.pumpAndSettle();
  }

  testWidgets('WORKER: el menú no ofrece vaciar historial', (tester) async {
    when(() => auth.state).thenReturn(
      const AuthAuthenticated(
        Identity(userId: 'u1', email: 'x@x', orgId: 'o1', role: 'WORKER'),
      ),
    );
    await openMenu(tester);
    expect(find.byKey(const Key('thread.clear_history')), findsNothing);
  });

  testWidgets('ADMIN: el menú ofrece "Vaciar historial"', (tester) async {
    await openMenu(tester);
    expect(find.byKey(const Key('thread.clear_history')), findsOneWidget);
    expect(find.text('Vaciar historial'), findsOneWidget);
  });

  testWidgets('elegirlo abre confirmación; cancelar no despacha nada', (
    tester,
  ) async {
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('thread.clear_history')));
    await tester.pumpAndSettle();

    expect(find.text('¿Vaciar historial?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => messages.add(any()));
    expect(find.text('¿Vaciar historial?'), findsNothing);
  });

  testWidgets('confirmar despacha MessagesClearHistoryRequested', (
    tester,
  ) async {
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('thread.clear_history')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread.clear_history.confirm')));
    await tester.pumpAndSettle();

    verify(() => messages.add(const MessagesClearHistoryRequested())).called(1);
    expect(find.text('¿Vaciar historial?'), findsNothing);
  });
}
