import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: Column(children: <Widget>[child])),
  );

  BoxDecoration decoOf(WidgetTester tester) {
    final box = tester.widget<Container>(
      find.byKey(const Key('chat_bubble.box')),
    );
    return box.decoration! as BoxDecoration;
  }

  testWidgets('mine: alinea a la derecha con surface3 y cola inferior '
      'derecha', (tester) async {
    await tester.pumpWidget(
      host(const ChatBubble(mine: true, child: Text('hola'))),
    );
    await tester.pump(AppTokens.durationBase); // asienta la animación

    expect(find.text('hola'), findsOneWidget);
    final align = tester.widget<Align>(
      find.ancestor(
        of: find.byKey(const Key('chat_bubble.box')),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.centerRight);
    final deco = decoOf(tester);
    expect(deco.color, AppTokens.surface3);
    final radius = deco.borderRadius! as BorderRadius;
    expect(radius.bottomRight.x, lessThan(radius.bottomLeft.x));
  });

  testWidgets('ajeno: alinea a la izquierda con surface2 y cola inferior '
      'izquierda', (tester) async {
    await tester.pumpWidget(
      host(const ChatBubble(mine: false, child: Text('qué tal'))),
    );
    await tester.pump(AppTokens.durationBase);

    final align = tester.widget<Align>(
      find.ancestor(
        of: find.byKey(const Key('chat_bubble.box')),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.centerLeft);
    final deco = decoOf(tester);
    expect(deco.color, AppTokens.surface2);
    final radius = deco.borderRadius! as BorderRadius;
    expect(radius.bottomLeft.x, lessThan(radius.bottomRight.x));
  });

  testWidgets('la entrada anima hacia opacidad plena', (tester) async {
    await tester.pumpWidget(
      host(const ChatBubble(mine: false, child: Text('x'))),
    );
    await tester.pump(AppTokens.durationBase);
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const Key('chat_bubble.box')),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1.0);
  });
}
