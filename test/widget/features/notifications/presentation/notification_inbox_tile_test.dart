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

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<NotificationsBloc>.value(
      value: bloc,
      child: Scaffold(body: NotificationInboxTile(item: _item)),
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
}
