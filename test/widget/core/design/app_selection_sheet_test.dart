import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/app_selection_sheet.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
import 'package:ataulfo/core/design/widgets/app_section_header.dart';

void main() {
  const sections = <AppSelectionSection<String>>[
    AppSelectionSection(
      header: 'Mensajes',
      options: <AppSelectionOption<String>>[
        AppSelectionOption(
          key: Key('sel.text'),
          value: 'text',
          title: 'Texto',
          caption: 'Un mensaje escrito',
          leading: Icon(Icons.notes, size: 20, color: AppTokens.text2),
        ),
        AppSelectionOption(
          key: Key('sel.image'),
          value: 'image',
          title: 'Imagen',
          caption: 'Una foto o captura',
        ),
      ],
    ),
    AppSelectionSection(
      header: 'Lógica',
      options: <AppSelectionOption<String>>[
        AppSelectionOption(
          key: Key('sel.cond'),
          value: 'cond',
          title: 'Condición de horario',
          caption: 'Ramifica según día y hora',
        ),
      ],
    ),
  ];

  /// Host con un botón que abre el sheet y captura su Future.
  Widget host(void Function(BuildContext) onTap) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  Future<Future<String?>> open(
    WidgetTester tester, {
    String? selected,
    String? searchHint,
  }) async {
    late Future<String?> result;
    await tester.pumpWidget(
      host(
        (context) => result = showAppSelectionSheet<String>(
          context,
          title: 'Tipo de paso',
          sections: sections,
          selected: selected,
          searchHint: searchHint,
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return result;
  }

  group('showAppSelectionSheet — anatomía', () {
    testWidgets('pinta título, encabezados de sección y filas con caption', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Tipo de paso'), findsOneWidget);
      // Secciones con el encabezado canónico del kit.
      expect(find.byType(AppSectionHeader), findsNWidgets(2));
      expect(find.text('Mensajes'), findsOneWidget);
      expect(find.text('Lógica'), findsOneWidget);
      expect(find.text('Texto'), findsOneWidget);
      expect(find.text('Un mensaje escrito'), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsOneWidget);
    });

    testWidgets('cada fila ofrece un blanco táctil de al menos 44px de alto', (
      tester,
    ) async {
      await open(tester);
      final size = tester.getSize(find.byKey(const Key('sel.image')));
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('la opción seleccionada muestra el check de marca', (
      tester,
    ) async {
      await open(tester, selected: 'image');
      final check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.color, AppTokens.primary);
      // Solo la fila seleccionada lo lleva.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('sel.image')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin searchHint no hay buscador', (tester) async {
      await open(tester);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('showAppSelectionSheet — resultado', () {
    testWidgets('tap en una opción cierra y devuelve su valor', (tester) async {
      final result = await open(tester);
      await tester.tap(find.byKey(const Key('sel.cond')));
      await tester.pumpAndSettle();
      expect(await result, 'cond');
      expect(find.text('Tipo de paso'), findsNothing);
    });

    testWidgets('descartar por scrim devuelve null', (tester) async {
      final result = await open(tester);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });

  group('showAppSelectionSheet — búsqueda', () {
    testWidgets('el buscador filtra filas y esconde secciones sin resultados', (
      tester,
    ) async {
      await open(tester, searchHint: 'Buscar tipo');
      expect(find.byType(AppSearchField), findsOneWidget);
      final search = tester.widget<AppSearchField>(find.byType(AppSearchField));
      expect(search.hint, 'Buscar tipo');
      await tester.enterText(find.byType(TextField), 'imag');
      await tester.pumpAndSettle();
      expect(find.text('Imagen'), findsOneWidget);
      expect(find.text('Texto'), findsNothing);
      // La sección Lógica se queda sin filas: su encabezado también calla.
      expect(find.text('Lógica'), findsNothing);
    });

    testWidgets('la búsqueda ignora acentos y mayúsculas', (tester) async {
      await open(tester, searchHint: 'Buscar tipo');
      await tester.enterText(find.byType(TextField), 'CONDICION');
      await tester.pumpAndSettle();
      expect(find.text('Condición de horario'), findsOneWidget);
    });

    testWidgets('también busca en la caption', (tester) async {
      await open(tester, searchHint: 'Buscar tipo');
      await tester.enterText(find.byType(TextField), 'ramifica');
      await tester.pumpAndSettle();
      expect(find.text('Condición de horario'), findsOneWidget);
      expect(find.text('Texto'), findsNothing);
    });

    testWidgets('sin coincidencias avisa "Sin resultados"', (tester) async {
      await open(tester, searchHint: 'Buscar tipo');
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('elegir una fila filtrada devuelve su valor', (tester) async {
      final result = await open(tester, searchHint: 'Buscar tipo');
      await tester.enterText(find.byType(TextField), 'horario');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sel.cond')));
      await tester.pumpAndSettle();
      expect(await result, 'cond');
    });
  });
}
