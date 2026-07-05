import 'package:ataulfo/core/design/widgets/copy_text_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Intercepta `Clipboard.setData` del canal de plataforma para afirmar el
  /// texto copiado en un test puro de widgets (sin portapapeles real).
  List<String> interceptClipboard(WidgetTester tester) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('long-press abre la hoja; Copiar copia y avisa', (tester) async {
    final copied = interceptClipboard(tester);
    await tester.pumpWidget(
      host(
        const CopyableBubble(
          text: 'hola **mundo**',
          keyId: 'x',
          child: Text('burbuja'),
        ),
      ),
    );

    await tester.longPress(find.text('burbuja'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copy.x.copy')), findsOneWidget);
    expect(find.byKey(const Key('copy.x.select')), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy.x.copy')));
    await tester.pumpAndSettle();
    expect(copied, <String>['hola **mundo**']);
    expect(find.text('Mensaje copiado'), findsOneWidget);
  });

  testWidgets('copias seguidas reemplazan el aviso en vez de encolarlo', (
    tester,
  ) async {
    interceptClipboard(tester);
    late BuildContext ctx;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await copyTextToClipboard(ctx, 'uno', confirm: 'Aviso uno');
    await tester.pump();
    await copyTextToClipboard(ctx, 'dos', confirm: 'Aviso dos');
    await tester.pump();
    // Sin reemplazo, "Aviso dos" espera en cola a que "Aviso uno" agote sus
    // segundos: copiar dos veces se sentiría sin respuesta.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Aviso dos'), findsOneWidget);
    expect(find.text('Aviso uno'), findsNothing);
  });

  testWidgets('Seleccionar texto abre la hoja con SelectableText', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const CopyableBubble(
          text: 'RFC AOSE041119',
          keyId: 'y',
          child: Text('burbuja'),
        ),
      ),
    );
    await tester.longPress(find.text('burbuja'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy.y.select')));
    await tester.pumpAndSettle();
    final sel = tester.widget<SelectableText>(
      find.byKey(const Key('copy.select_sheet.text')),
    );
    expect(sel.data, 'RFC AOSE041119');
  });

  testWidgets('texto vacío/whitespace no engancha el long-press', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const CopyableBubble(text: '   ', keyId: 'z', child: Text('burbuja')),
      ),
    );
    await tester.longPress(find.text('burbuja'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copy.z.copy')), findsNothing);
  });
}
