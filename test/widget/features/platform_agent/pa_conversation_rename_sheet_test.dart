import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/features/platform_agent/presentation/widgets/pa_conversation_rename_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, String initial) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () =>
                PaConversationRenameSheet.open(ctx, initial: initial),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('es un form-sheet del kit (AppTextField + AppButton.filled)', (
    tester,
  ) async {
    await _open(tester, 'Operación');
    expect(find.text('Renombrar conversación'), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
    // Prefijado con el título actual.
    expect(find.text('Operación'), findsOneWidget);
  });

  testWidgets('Guardar cierra el sheet devolviendo el texto (recortado)', (
    tester,
  ) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                captured = await PaConversationRenameSheet.open(
                  ctx,
                  initial: 'Viejo',
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('pa.history.rename.field')),
      '  Nuevo nombre  ',
    );
    await tester.tap(find.byKey(const Key('pa.history.rename.confirm')));
    await tester.pumpAndSettle();

    expect(captured, 'Nuevo nombre');
    expect(find.byType(AppTextField), findsNothing);
  });
}
