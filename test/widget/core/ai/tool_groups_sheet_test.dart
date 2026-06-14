import 'package:ataulfo/core/ai/tool_groups_sheet.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Abre el sheet vía showModalBottomSheet y captura el resultado del pop (la
  // deny-list de este nivel). El call site real abre así, no pumpea el widget
  // suelto: el pop necesita una ruta.
  Future<List<String>?> openAndEdit(
    WidgetTester tester, {
    required List<String> initial,
    List<String> locked = const <String>[],
    required Future<void> Function(WidgetTester) edit,
  }) async {
    // Viewport alto: el sheet lista 10 filas + cabecera + botón; con la
    // ventana por defecto algunas filas quedan fuera del viewport del ListView
    // (lazy) y find.byKey no las hallaría. Con espacio de sobra, todo se monta.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ToolGroupsSheet(
                    initialDisabledGroups: initial,
                    lockedDisabledGroups: locked,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Permisos de herramientas'), findsOneWidget);
    await edit(tester);
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets(
    'Guardar devuelve la deny-list: re-habilita uno apagado y deshabilita otro',
    (tester) async {
      final result = await openAndEdit(
        tester,
        initial: const <String>['flujos'],
        edit: (t) async {
          // flujos arranca apagado ⇒ tocarlo lo HABILITA (sale de la deny-list).
          await tapKey(t, 'tool_groups.sheet.option.flujos');
          // notas arranca habilitado ⇒ tocarlo lo DESHABILITA.
          await tapKey(t, 'tool_groups.sheet.option.notas');
          await tapKey(t, 'tool_groups.sheet.save');
        },
      );
      expect(result, <String>['notas']);
    },
  );

  testWidgets(
    'un grupo bloqueado por la plantilla no es tappable ni entra en el resultado',
    (tester) async {
      final result = await openAndEdit(
        tester,
        initial: const <String>[],
        locked: const <String>['etiquetas'],
        edit: (t) async {
          // Tocar el grupo bloqueado no hace nada (onTap null).
          await tapKey(t, 'tool_groups.sheet.option.etiquetas');
          // Deshabilitar uno propio.
          await tapKey(t, 'tool_groups.sheet.option.hora');
          await tapKey(t, 'tool_groups.sheet.save');
        },
      );
      // El bloqueado (etiquetas) NUNCA entra en la deny-list de este nivel.
      expect(result, <String>['hora']);
    },
  );
}
