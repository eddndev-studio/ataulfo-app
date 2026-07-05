import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/util/smart_timestamp.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:ataulfo/features/notifications/presentation/widgets/notification_inbox_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
    registerFallbackValue(const NotificationMarkReadRequested('x'));
  });

  late _MockNotificationsBloc bloc;

  setUp(() {
    bloc = _MockNotificationsBloc();
  });

  Widget host([NotificationInboxItem? item]) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<NotificationsBloc>.value(
      value: bloc,
      child: Scaffold(body: NotificationInboxTile(item: item ?? _item)),
    ),
  );

  testWidgets('título y timestamp salen del textTheme, no de estilos crudos', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final context = tester.element(find.byType(NotificationInboxTile));
    final textTheme = Theme.of(context).textTheme;

    // Título de fila = titleMedium del theme (anatomía canónica), no un
    // TextStyle literal w700.
    final title = tester.widget<Text>(find.text('Bot desconectado'));
    expect(title.style, textTheme.titleMedium);

    // Timestamp secundario = labelSmall atenuado a textDisabled, no un calco
    // manual de captionSize/captionWeight.
    final ts = tester.widget<Text>(
      find.text(smartTimestamp(_item.updatedAt.millisecondsSinceEpoch)),
    );
    expect(
      ts.style,
      textTheme.labelSmall?.copyWith(color: AppTokens.textDisabled),
    );
  });

  testWidgets('body y contador de eventos salen del textTheme', (tester) async {
    final collapsed = NotificationInboxItem(
      id: 'ni-2',
      eventType: NotificationEventType.botDisconnected,
      title: 'Bot desconectado',
      body: 'El bot perdió conexión',
      priority: NotificationPriority.high,
      count: 3,
      status: NotificationInboxStatus.unread,
      createdAt: DateTime.utc(2026, 6, 3, 12),
      updatedAt: DateTime.utc(2026, 6, 3, 12),
    );
    await tester.pumpWidget(host(collapsed));

    final context = tester.element(find.byType(NotificationInboxTile));
    final textTheme = Theme.of(context).textTheme;

    // Copy secundaria = bodyMedium del theme atenuado, no TextStyle crudo.
    final body = tester.widget<Text>(find.text('El bot perdió conexión'));
    expect(body.style, textTheme.bodyMedium?.copyWith(color: AppTokens.text2));

    // El contador de eventos colapsados es meta-info: mismas métricas de
    // bodyMedium, atenuado a textDisabled como el timestamp.
    final count = tester.widget<Text>(find.text('3 eventos'));
    expect(
      count.style,
      textTheme.bodyMedium?.copyWith(color: AppTokens.textDisabled),
    );
  });

  testWidgets('el detalle técnico expandido sale del textTheme', (
    tester,
  ) async {
    final withDetail = NotificationInboxItem(
      id: 'ni-3',
      eventType: NotificationEventType.flowFailed,
      title: 'Flujo fallido',
      body: 'No se pudo completar el flujo',
      priority: NotificationPriority.high,
      count: 1,
      status: NotificationInboxStatus.unread,
      createdAt: DateTime.utc(2026, 6, 3, 12),
      updatedAt: DateTime.utc(2026, 6, 3, 12),
      payload: const <String, String>{
        'code': 'send_failed',
        'detail': 'upload failed with status code 400',
      },
    );
    await tester.pumpWidget(host(withDetail));

    await tester.tap(find.byKey(const Key('notifications.item.ni-3.expand')));
    await tester.pump();

    final context = tester.element(find.byType(NotificationInboxTile));
    final textTheme = Theme.of(context).textTheme;

    // Código estable = bodyMedium del theme en monospace w700, no un
    // TextStyle crudo.
    final code = tester.widget<Text>(find.text('send_failed'));
    expect(
      code.style,
      textTheme.bodyMedium?.copyWith(
        color: AppTokens.text2,
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
      ),
    );

    // Razón cruda del servidor = volcado técnico: bodySmall en monospace,
    // como el error crudo del historial de ejecuciones.
    final detail = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(
      detail.style,
      textTheme.bodySmall?.copyWith(
        color: AppTokens.text2,
        fontFamily: 'monospace',
      ),
    );
  });
}
