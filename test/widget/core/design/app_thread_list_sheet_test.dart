import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_thread_list_sheet.dart';

const _items = <AppThreadListItem>[
  AppThreadListItem(id: 'c1', title: 'Saludo inicial'),
  AppThreadListItem(id: 'c2', title: 'Sobre envíos'),
];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<String>? onSelect,
    ValueChanged<String>? onRename,
    ValueChanged<String>? onDelete,
    String activeId = 'c1',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppThreadListSheet(
            keyPrefix: 'threads',
            items: _items,
            activeId: activeId,
            onSelect: onSelect ?? (_) {},
            onRename: onRename,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }

  testWidgets('lista los hilos con sus keys y la key de la lista', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('threads.list')), findsOneWidget);
    expect(find.byKey(const Key('threads.item.c1')), findsOneWidget);
    expect(find.byKey(const Key('threads.item.c2')), findsOneWidget);
    expect(find.text('Saludo inicial'), findsOneWidget);
    expect(find.text('Sobre envíos'), findsOneWidget);
  });

  testWidgets('el hilo activo va marcado con radio_button_checked en primary', (
    tester,
  ) async {
    await pump(tester, activeId: 'c2');
    final icon = tester.widget<Icon>(find.byIcon(Icons.radio_button_checked));
    expect(icon.color, AppTokens.primary);
    // El inactivo lleva otro glifo.
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
  });

  testWidgets('tap en un hilo dispara onSelect con su id', (tester) async {
    String? selected;
    await pump(tester, onSelect: (id) => selected = id);
    await tester.tap(find.byKey(const Key('threads.item.c2')));
    await tester.pumpAndSettle();
    expect(selected, 'c2');
  });

  testWidgets('sin onRename/onDelete NO monta el menú por hilo', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('threads.menu.c1')), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('con menú: Renombrar dispara onRename(id)', (tester) async {
    String? renamed;
    await pump(tester, onRename: (id) => renamed = id, onDelete: (_) {});
    await tester.tap(find.byKey(const Key('threads.menu.c2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar').last);
    await tester.pumpAndSettle();
    expect(renamed, 'c2');
  });

  testWidgets('con menú: Eliminar dispara onDelete(id)', (tester) async {
    String? deleted;
    await pump(tester, onRename: (_) {}, onDelete: (id) => deleted = id);
    await tester.tap(find.byKey(const Key('threads.menu.c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(deleted, 'c1');
  });
}
