import 'package:ataulfo/core/design/safe_bottom.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeBottomContext.safeBottomInset', () {
    testWidgets('devuelve viewPadding.bottom (ignora teclado)', (tester) async {
      double? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 24),
            viewInsets: EdgeInsets.only(bottom: 0),
          ),
          child: Builder(
            builder: (context) {
              captured = context.safeBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, 24);
    });

    testWidgets('ignora viewInsets aunque el teclado esté abierto', (
      tester,
    ) async {
      double? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            // viewInsets > 0 simula teclado virtual abierto, pero
            // safeBottomInset es para PAGES (no para sheets) — no debe
            // sumar el teclado.
            viewPadding: EdgeInsets.only(bottom: 16),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Builder(
            builder: (context) {
              captured = context.safeBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, 16);
    });

    testWidgets('devuelve 0 cuando no hay gesture-nav ni teclado', (
      tester,
    ) async {
      double? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              captured = context.safeBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, 0);
    });
  });

  group('SafeBottomContext.sheetBottomInset', () {
    testWidgets('teclado abierto > nav: gana el teclado', (tester) async {
      double? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 24),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Builder(
            builder: (context) {
              captured = context.sheetBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, 300);
    });

    testWidgets('teclado cerrado: gana la gesture-nav', (tester) async {
      double? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 32),
            viewInsets: EdgeInsets.only(bottom: 0),
          ),
          child: Builder(
            builder: (context) {
              captured = context.sheetBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, 32);
    });

    testWidgets('ambos en 0: devuelve 0', (tester) async {
      double? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              captured = context.sheetBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(captured, 0);
    });
  });
}
