import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/motion.dart';
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

  testWidgets('acepta un focusNode externo que refleja el foco del campo', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      host(
        AppChatComposer(
          onSend: (_) {},
          focusNode: focus,
          fieldKey: const Key('c.field'),
        ),
      ),
    );

    expect(focus.hasFocus, isFalse);
    await tester.tap(find.byKey(const Key('c.field')));
    await tester.pump();
    // El caller observa el foco por su propio nodo (para intercambiar teclado
    // por otra superficie, p. ej.).
    expect(focus.hasFocus, isTrue);
  });

  group('micro-animaciones del slot final', () {
    Widget composerWithMic({bool motion = true}) => AppMotion(
      enabled: motion,
      child: host(
        AppChatComposer(
          onSend: (_) {},
          fieldKey: const Key('c.field'),
          sendKey: const Key('c.send'),
          emptyTrailing: IconButton(
            key: const Key('c.mic'),
            icon: const Icon(Icons.mic_none),
            onPressed: () {},
          ),
        ),
      ),
    );

    testWidgets('mic↔send transiciona con el switcher del kit y asienta en '
        'el estado correcto', (tester) async {
      await tester.pumpWidget(composerWithMic());

      expect(find.byKey(const Key('c.mic')), findsOneWidget);
      expect(find.byKey(const Key('c.send')), findsNothing);

      await tester.enterText(find.byKey(const Key('c.field')), 'hola');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('c.send')), findsOneWidget);
      expect(find.byKey(const Key('c.mic')), findsNothing);
      // El intercambio lo conduce el switcher del kit (scale+fade), no un
      // swap seco de subárboles.
      expect(
        find.descendant(
          of: find.byKey(const Key('app_chat_composer.bar')),
          matching: find.byType(AnimatedSwitcher),
        ),
        findsOneWidget,
      );
    });

    testWidgets('con AppMotion apagado el intercambio es instantáneo '
        '(un frame, sin transición)', (tester) async {
      await tester.pumpWidget(composerWithMic(motion: false));

      await tester.enterText(find.byKey(const Key('c.field')), 'hola');
      await tester.pump();

      expect(find.byKey(const Key('c.send')), findsOneWidget);
      expect(find.byKey(const Key('c.mic')), findsNothing);
    });

    testWidgets('el fill del botón enviar hace bloom animado: surface3 sin '
        'texto, primary con texto', (tester) async {
      await tester.pumpWidget(
        host(
          AppChatComposer(
            onSend: (_) {},
            fieldKey: const Key('c.field'),
            sendKey: const Key('c.send'),
          ),
        ),
      );

      AnimatedContainer fill() => tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('app_chat_composer.bar')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      // AnimatedContainer pliega `color:` dentro de su decoration.
      Color? colorOf(AnimatedContainer c) =>
          (c.decoration as BoxDecoration?)?.color;

      expect(colorOf(fill()), AppTokens.surface3);

      await tester.enterText(find.byKey(const Key('c.field')), 'hola');
      await tester.pumpAndSettle();

      expect(colorOf(fill()), AppTokens.primary);
    });

    testWidgets('el botón enviar encoge al presionarse (press-scale)', (
      tester,
    ) async {
      final sent = <String>[];
      await tester.pumpWidget(
        host(
          AppChatComposer(
            onSend: sent.add,
            fieldKey: const Key('c.field'),
            sendKey: const Key('c.send'),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('c.field')), 'hola');
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('c.send'))),
      );
      await tester.pump();
      final scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byKey(const Key('app_chat_composer.bar')),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, 0.97);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sent, <String>['hola']);
    });
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
