import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_delivery_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(MessageStatus status) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: Center(child: MessageDeliveryIndicator(status: status)),
  ),
);

Icon _icon(WidgetTester tester) => tester.widget<Icon>(
  find.byKey(const ValueKey<String>('message_delivery_indicator.icon')),
);

void main() {
  testWidgets('enviado usa un tick neutro y semántica verbal', (tester) async {
    await tester.pumpWidget(_host(MessageStatus.sent));

    final icon = _icon(tester);
    expect(icon.icon, Icons.done);
    expect(icon.color, AppTokens.text2);
    expect(icon.semanticLabel, 'Enviado');
  });

  testWidgets('entregado usa doble tick neutro', (tester) async {
    await tester.pumpWidget(_host(MessageStatus.delivered));

    final icon = _icon(tester);
    expect(icon.icon, Icons.done_all);
    expect(icon.color, AppTokens.text2);
    expect(icon.semanticLabel, 'Entregado');
  });

  testWidgets('leído usa doble tick con el acento propio del chat', (
    tester,
  ) async {
    await tester.pumpWidget(_host(MessageStatus.read));

    final icon = _icon(tester);
    expect(icon.icon, Icons.done_all);
    expect(icon.color, AppTokens.chatAccent);
    expect(icon.semanticLabel, 'Leído');
  });

  testWidgets('fallido usa el glifo y color de peligro', (tester) async {
    await tester.pumpWidget(_host(MessageStatus.failed));

    final icon = _icon(tester);
    expect(icon.icon, Icons.error_outline);
    expect(icon.color, AppTokens.danger);
    expect(icon.semanticLabel, 'Falló');
  });
}
