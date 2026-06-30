import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/features/messages/presentation/widgets/voice_recording_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({double bottomInset = 0}) => MediaQuery(
    data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: bottomInset)),
    child: MaterialApp(
      home: Scaffold(
        body: VoiceRecordingBar(
          elapsed: const Stream<Duration>.empty(),
          amplitude: const Stream<double>.empty(),
          onCancel: () {},
          onSend: () {},
        ),
      ),
    ),
  );

  Container barContainer(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const Key('voice.recording.bar')));

  testWidgets(
    'la barra es un Container con relleno surface1 y divisor superior',
    (tester) async {
      await tester.pumpWidget(host());

      final container = barContainer(tester);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppTokens.surface1);
      expect(decoration.border, isA<Border>());
      expect((decoration.border! as Border).top.color, AppTokens.divider);
    },
  );

  testWidgets('el padding inferior reserva el inset de la nav del sistema', (
    tester,
  ) async {
    await tester.pumpWidget(host(bottomInset: 48));

    final container = barContainer(tester);
    final padding = container.padding! as EdgeInsets;
    // sp2 base + 48 de viewPadding inferior: supera el inset crudo.
    expect(padding.bottom, greaterThanOrEqualTo(48 + AppTokens.sp2));
  });

  testWidgets('sin inset el padding inferior es solo el base sp2', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final container = barContainer(tester);
    final padding = container.padding! as EdgeInsets;
    expect(padding.bottom, AppTokens.sp2);
  });
}
