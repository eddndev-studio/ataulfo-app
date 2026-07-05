import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/templates/presentation/widgets/template_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(String prompt) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: TemplatePromptCard(prompt: prompt)),
  );

  testWidgets('prompt vacío: placeholder en itálica, sin "Ver completo"', (
    tester,
  ) async {
    await tester.pumpWidget(host(''));

    expect(find.text('Sin prompt definido'), findsOneWidget);
    expect(find.text('Ver completo'), findsNothing);
  });

  testWidgets('con prompt: encabezado, meta de tamaño, preview y acción', (
    tester,
  ) async {
    await tester.pumpWidget(host('Eres un asistente amable.'));

    expect(find.text('Prompt del sistema'), findsOneWidget);
    // 25 caracteres → meta en caracteres.
    expect(find.text('25 caracteres'), findsOneWidget);
    expect(find.text('Ver completo'), findsOneWidget);

    // El preview recorta a lo sumo 8 líneas; no pinta el prompt completo inline.
    final preview = tester.widget<Text>(
      find.byKey(const Key('template_ai.prompt.preview')),
    );
    expect(preview.maxLines, 8);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('prompt largo: la meta se abrevia en miles', (tester) async {
    final long = 'x' * 3400;
    await tester.pumpWidget(host(long));

    expect(find.text('3.4k caracteres'), findsOneWidget);
  });

  testWidgets('"Ver completo" abre un sheet con el prompt completo y copiar', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    const prompt = 'Instrucciones detalladas del sistema para el asistente.';
    await tester.pumpWidget(host(prompt));

    await tester.tap(find.text('Ver completo'));
    await tester.pumpAndSettle();

    // El completo vive en el sheet, seleccionable.
    final sheetText = find.byType(SelectableText);
    expect(sheetText, findsOneWidget);
    expect(tester.widget<SelectableText>(sheetText).data, prompt);

    await tester.tap(find.byKey(const Key('template_ai.prompt.copy')));
    await tester.pumpAndSettle();

    // Copió el prompt al portapapeles y cerró el sheet.
    expect(calls, hasLength(1));
    expect((calls.first.arguments as Map)['text'], prompt);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Prompt copiado'), findsOneWidget);
  });
}
