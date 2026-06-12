import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: Column(children: <Widget>[const Spacer(), child])),
  );

  testWidgets('manda el texto recortado al tocar enviar y limpia el campo', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(
      host(
        AppChatComposer(
          hint: 'Mensaje',
          onSend: sent.add,
          fieldKey: const Key('c.field'),
          sendKey: const Key('c.send'),
        ),
      ),
    );

    expect(find.text('Mensaje'), findsOneWidget); // hint visible

    await tester.enterText(find.byKey(const Key('c.field')), '  hola  ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('c.send')));
    await tester.pump();

    expect(sent, <String>['hola']);
    final field = tester.widget<TextField>(find.byKey(const Key('c.field')));
    expect(field.controller!.text, isEmpty); // limpiado tras enviar
  });

  testWidgets('sin texto (o solo espacios) enviar no dispara', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(
      host(AppChatComposer(onSend: sent.add, sendKey: const Key('c.send'))),
    );

    await tester.tap(find.byKey(const Key('c.send')));
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('enabled=false bloquea el campo y el botón', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(
      host(
        AppChatComposer(
          onSend: sent.add,
          enabled: false,
          fieldKey: const Key('c.field'),
          sendKey: const Key('c.send'),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byKey(const Key('c.field')));
    expect(field.enabled, isFalse);
    await tester.tap(find.byKey(const Key('c.send')), warnIfMissed: false);
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('pinta las acciones leading antes del campo', (tester) async {
    await tester.pumpWidget(
      host(
        AppChatComposer(
          onSend: (_) {},
          leading: <Widget>[
            IconButton(
              key: const Key('c.attach'),
              icon: const Icon(Icons.image_outlined),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('c.attach')), findsOneWidget);
  });

  testWidgets('acepta un controller externo (inserciones del caller)', (
    tester,
  ) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    final sent = <String>[];
    await tester.pumpWidget(
      host(
        AppChatComposer(
          controller: ctrl,
          onSend: sent.add,
          sendKey: const Key('c.send'),
        ),
      ),
    );

    ctrl.text = 'desde fuera';
    await tester.pump();
    await tester.tap(find.byKey(const Key('c.send')));
    await tester.pump();
    expect(sent, <String>['desde fuera']);
  });

  testWidgets('la barra usa surface1 con divisor superior (idioma del kit)', (
    tester,
  ) async {
    await tester.pumpWidget(host(AppChatComposer(onSend: (_) {})));

    final bar = tester.widget<Container>(
      find.byKey(const Key('app_chat_composer.bar')),
    );
    final deco = bar.decoration! as BoxDecoration;
    expect(deco.color, AppTokens.surface1);
    expect(deco.border!.top.color, AppTokens.divider);
  });
}
