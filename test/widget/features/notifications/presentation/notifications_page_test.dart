import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/util/smart_timestamp.dart';
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

final _alertItem = NotificationInboxItem(
  id: 'ni-2',
  eventType: NotificationEventType.agentAlert,
  botId: 'b1',
  chatLid: '5215550000001',
  title: 'El bot pide ayuda',
  body: 'El cliente reporta un pago',
  priority: NotificationPriority.high,
  count: 1,
  status: NotificationInboxStatus.unread,
  createdAt: DateTime.utc(2026, 6, 12, 12),
  updatedAt: DateTime.utc(2026, 6, 12, 12),
);

final _flowFailedItem = NotificationInboxItem(
  id: 'ni-3',
  eventType: NotificationEventType.flowFailed,
  botId: 'b1',
  chatLid: '5215550000002',
  title: 'Flujo "Bienvenida" fallido',
  body: 'No se pudo enviar el archivo. Reintenta en un momento.',
  priority: NotificationPriority.high,
  count: 1,
  status: NotificationInboxStatus.unread,
  createdAt: DateTime.utc(2026, 6, 14, 9),
  updatedAt: DateTime.utc(2026, 6, 14, 9),
  payload: const <String, String>{
    'code': 'send_upload_rejected',
    'detail': 'upload failed with status code 400',
    'flowName': 'Bienvenida',
  },
);

NotificationInboxItem _failed(String id) => NotificationInboxItem(
  id: id,
  eventType: NotificationEventType.flowFailed,
  botId: 'b1',
  chatLid: '5215550000002',
  title: 'Flujo fallido $id',
  body: 'No se pudo enviar el archivo.',
  priority: NotificationPriority.high,
  count: 1,
  status: NotificationInboxStatus.unread,
  createdAt: DateTime.utc(2026, 6, 14, 9),
  updatedAt: DateTime.utc(2026, 6, 14, 9),
  payload: const <String, String>{
    'code': 'send_upload_rejected',
    'detail': 'upload failed with status code 400',
  },
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
    // El spinner de página es el primitivo canónico del kit, con el tinte de
    // marca (no el azul default de Material).
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
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

  testWidgets('el ítem muestra su marca de tiempo', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(NotificationsLoaded(items: <NotificationInboxItem>[_item]));

    await tester.pumpWidget(host());

    expect(
      find.text(smartTimestamp(_item.updatedAt.millisecondsSinceEpoch)),
      findsOneWidget,
    );
  });

  testWidgets(
    'detalle técnico colapsado por defecto, se expande con su botón',
    (tester) async {
      when(() => bloc.state).thenReturn(
        NotificationsLoaded(items: <NotificationInboxItem>[_flowFailedItem]),
      );

      await tester.pumpWidget(host());

      // Colapsado: el code/detail crudo NO se ve hasta expandir.
      expect(find.text('send_upload_rejected'), findsNothing);
      expect(find.textContaining('status code 400'), findsNothing);

      await tester.tap(find.byKey(const Key('notifications.item.ni-3.expand')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifications.item.ni-3.detail')),
        findsOneWidget,
      );
      expect(find.text('send_upload_rejected'), findsOneWidget);
      expect(find.textContaining('status code 400'), findsOneWidget);
    },
  );

  testWidgets('expandir el detalle NO marca leído (sin conflicto de tap)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      NotificationsLoaded(items: <NotificationInboxItem>[_flowFailedItem]),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('notifications.item.ni-3.expand')));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(const NotificationMarkReadRequested('ni-3')));
  });

  testWidgets(
    'el estado de expansión no migra a otro ítem al recomponerse la lista',
    (tester) async {
      final a = _failed('ni-a');
      final b = _failed('ni-b');
      final c = _failed('ni-c');
      final controller = StreamController<NotificationsState>();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: NotificationsLoaded(
          items: <NotificationInboxItem>[a, b, c],
        ),
      );

      await tester.pumpWidget(host());

      // Expandir el de en medio (b): por posición, su estado caería sobre c al
      // quitarse un ítem anterior.
      await tester.tap(find.byKey(const Key('notifications.item.ni-b.expand')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('notifications.item.ni-b.detail')),
        findsOneWidget,
      );

      // Quitar el primero (a): la lista se recompone a [b, c]. Con una key
      // estable por id, el detalle abierto NO se cuela en c, que nunca se
      // expandió (sin key, el estado _expanded migraría por posición).
      controller.add(NotificationsLoaded(items: <NotificationInboxItem>[b, c]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notifications.item.ni-c.detail')),
        findsNothing,
      );
    },
  );

  testWidgets('empty muestra estado vacío', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotificationsLoaded(items: <NotificationInboxItem>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notifications.empty')), findsOneWidget);
    // El vacío rico canónico del kit; Preferencias sigue disponible debajo.
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Preferencias'), findsOneWidget);
  });

  testWidgets('el vacío ofrece pull-to-refresh que recarga', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotificationsLoaded(items: <NotificationInboxItem>[]));

    await tester.pumpWidget(host());

    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => bloc.add(const NotificationsLoadRequested())).called(1);
  });

  testWidgets('failed muestra retry', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const NotificationsFailed(NotificationsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('notifications.error')), findsOneWidget);
    // La card de error es el primitivo canónico del kit.
    expect(find.byType(AppErrorState), findsOneWidget);
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

  testWidgets('un agent.alert se pinta con su ícono y deep-link al chat', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      NotificationsLoaded(items: <NotificationInboxItem>[_alertItem]),
    );
    String? pushed;
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: <RouteBase>[
        GoRoute(
          path: '/inbox',
          builder: (_, _) => BlocProvider<NotificationsBloc>.value(
            value: bloc,
            child: const Scaffold(body: NotificationsPage()),
          ),
        ),
        GoRoute(
          path: '/bots/:id/sessions/:chatLid',
          builder: (_, state) {
            pushed = state.uri.toString();
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('El bot pide ayuda'), findsOneWidget);
    expect(find.byIcon(Icons.support_agent_outlined), findsOneWidget);

    await tester.tap(find.text('El bot pide ayuda'));
    await tester.pumpAndSettle();
    expect(pushed, '/bots/b1/sessions/5215550000001');
  });

  testWidgets('la lista reserva el inset inferior del sistema en su padding', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(NotificationsLoaded(items: <NotificationInboxItem>[_item]));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
              child: BlocProvider<NotificationsBloc>.value(
                value: bloc,
                child: const NotificationsPage(),
              ),
            ),
          ),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding?.resolve(TextDirection.ltr).bottom, AppTokens.sp6 + 34);
  });
}
