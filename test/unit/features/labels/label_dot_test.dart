import 'package:ataulfo/features/labels/presentation/widgets/label_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLabelHex', () {
    test('#RRGGBB → Color opaco', () {
      expect(parseLabelHex('#34B7F1'), const Color(0xFF34B7F1));
      expect(parseLabelHex('34B7F1'), const Color(0xFF34B7F1)); // sin #
    });

    test('#AARRGGBB respeta el alpha', () {
      expect(parseLabelHex('#8034B7F1'), const Color(0x8034B7F1));
    });

    test('minúsculas válidas', () {
      expect(parseLabelHex('#ff0000'), const Color(0xFFFF0000));
    });

    test('hex inválido → fallback estable (no crashea)', () {
      final c = parseLabelHex('no-soy-hex');
      expect(c, isA<Color>());
      expect(parseLabelHex(''), isA<Color>());
      expect(parseLabelHex('#12'), isA<Color>());
    });
  });

  testWidgets('LabelDot pinta un círculo con el color del hex', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LabelDot(hex: '#34B7F1')),
      ),
    );
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF34B7F1));
    expect(decoration.shape, BoxShape.circle);
  });
}
