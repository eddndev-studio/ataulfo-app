import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required TextEditingController controller,
    String hint = 'Buscar asistentes por nombre…',
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Key? clearButtonKey,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: AppSearchField(
            hint: hint,
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            clearButtonKey: clearButtonKey,
          ),
        ),
      ),
    );
  }

  testWidgets('fija la anatomía compacta y contextual de búsqueda', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pump(tester, controller: controller);

    expect(find.byType(AppTextField), findsOneWidget);
    final field = tester.widget<AppTextField>(find.byType(AppTextField));
    expect(field.label, isNull);
    expect(field.hint, 'Buscar asistentes por nombre…');
    expect(field.prefixIcon, Icons.search);
    expect(field.textInputAction, TextInputAction.search);
    expect(field.autocorrect, isFalse);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byTooltip('Limpiar búsqueda'), findsNothing);
  });

  testWidgets(
    'limpiar conserva la altura, ofrece 48 px y notifica el valor vacío',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      const clearKey = Key('search.clear');

      await pump(
        tester,
        controller: controller,
        onChanged: changes.add,
        clearButtonKey: clearKey,
      );
      final emptyHeight = tester.getSize(find.byType(AppSearchField)).height;

      await tester.enterText(find.byType(TextField), 'ventas');
      await tester.pump();

      expect(changes, <String>['ventas']);
      expect(find.byKey(clearKey), findsOneWidget);
      final clearSize = tester.getSize(find.byKey(clearKey));
      expect(clearSize.width, greaterThanOrEqualTo(48));
      expect(clearSize.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.byType(AppSearchField)).height,
        emptyHeight,
      );

      await tester.tap(find.byKey(clearKey));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(changes, <String>['ventas', '']);
      expect(find.byKey(clearKey), findsNothing);
      expect(
        tester.getSize(find.byType(AppSearchField)).height,
        emptyHeight,
      );
    },
  );

  testWidgets('reacciona a cambios externos y propaga submit', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;

    await pump(
      tester,
      controller: controller,
      onSubmitted: (value) => submitted = value,
    );

    controller.text = 'soporte';
    await tester.pump();
    expect(find.byTooltip('Limpiar búsqueda'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submitted, 'soporte');
  });
}
