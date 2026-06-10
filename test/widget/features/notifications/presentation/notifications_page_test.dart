import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/failures/notifications_failure.dart';
import 'package:ataulfo/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:ataulfo/features/notifications/presentation/pages/notifications_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsBloc
    extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

final _item = NotificationInboxItem(
  id: 'ni-1',
  eventType: NotificationEventType.botDisconnected,
  title: 'Bot desconectado',
  body: 'El bot perdió conexión',
  priority: NotificationPriority.high,
  count: 1,
  status: NotificationInboxStatus.unread,
  createdAt: DateTime.utc(2026, 6, 3, 12),
  updatedAt: DateTime.utc(2026, 6, 3, 12),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationsLoadRequested());
    registerFallbackValue(const NotificationMarkReadRequested('x'));
    registerFallbackValue(const NotificationsMarkAllReadRequested());
  });

  late _MockNotificationsBloc bloc;

  setUp(() {
    bloc = _MockNotificationsBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<NotificationsBloc>.value(
      value: bloc,
      child: const Scaffold(body: NotificationsPage()),
    ),
  );

  testWidgets('loading muestra estado de carga', (tester) async {
    when(() => bloc.state).thenReturn(const NotificationsLoading());

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notifications.loading')), findsOneWidget);
  });

  testWidgets('loaded renderiza item y mark-all', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(NotificationsLoaded(items: <NotificationInboxItem>[_item]));

    await tester.pumpWidget(host());

    expect(find.text('Bot desconectado'), findsOneWidget);
    expect(find.text('El bot perdió conexión'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Marcar todo leído'), findsOneWidget);
  });

  testWidgets('el ítem NO finge navegación: sin chevron, ícono de hecho', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(NotificationsLoaded(items: <NotificationInboxItem>[_item]));

    await tester.pumpWidget(host());

    // El tap marca como leída (no navega): un chevron prometería un detalle
    // que no existe.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.done_outlined), findsWidgets);
  });

  testWidgets('la lista ofrece pull-to-refresh', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(NotificationsLoaded(items: <NotificationInboxItem>[_item]));

    await tester.pumpWidget(host());

    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('tap item marca leído', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(NotificationsLoaded(items: <NotificationInboxItem>[_item]));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('notifications.item.ni-1')));

    verify(
      () => bloc.add(const NotificationMarkReadRequested('ni-1')),
    ).called(1);
  });

  testWidgets('empty muestra estado vacío', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotificationsLoaded(items: <NotificationInboxItem>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notifications.empty')), findsOneWidget);
  });

  testWidgets('failed muestra retry', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotificationsFailed(NotificationsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notifications.error')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    verify(() => bloc.add(const NotificationsLoadRequested())).called(1);
  });

  testWidgets('tap Preferencias apila /notification-preferences', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotificationsLoaded(items: <NotificationInboxItem>[]));
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, _) => BlocProvider<NotificationsBloc>.value(
            value: bloc,
            child: const Scaffold(body: NotificationsPage()),
          ),
        ),
        GoRoute(
          path: '/notification-preferences',
          builder: (_, _) => const Text('Preferencias route'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
    await tester.tap(find.widgetWithText(AppButton, 'Preferencias'));
    await tester.pumpAndSettle();

    expect(find.text('Preferencias route'), findsOneWidget);
  });
}
