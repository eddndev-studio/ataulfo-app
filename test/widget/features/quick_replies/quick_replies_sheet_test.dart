import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/quick_replies/domain/entities/quick_reply.dart';
import 'package:ataulfo/features/quick_replies/presentation/widgets/quick_replies_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuickReply _qr({
  String id = '61',
  String shortcut = 'saludo',
  String message = 'Hola, ¿en qué te ayudo?',
  bool deleted = false,
}) => QuickReply(
  waQuickReplyId: id,
  shortcut: shortcut,
  message: message,
  deleted: deleted,
);

void main() {
  Widget host(List<QuickReply> items, {void Function(String?)? onResult}) =>
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final r = await QuickRepliesSheet.open(context, items);
                  onResult?.call(r);
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('lista activos (shortcut + message) y oculta tombstones', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(<QuickReply>[
        _qr(shortcut: 'saludo', message: 'Hola'),
        _qr(id: '62', shortcut: 'despedida', message: 'Adiós'),
        _qr(id: '63', shortcut: 'borrada', message: 'Tombstone', deleted: true),
      ]),
    );
    await openSheet(tester);

    expect(find.text('saludo'), findsOneWidget);
    expect(find.text('Hola'), findsOneWidget);
    expect(find.text('despedida'), findsOneWidget);
    // El tombstone NO se ofrece.
    expect(find.text('borrada'), findsNothing);
    expect(find.text('Tombstone'), findsNothing);
  });

  testWidgets('sin activos (todo tombstone) → copy de vacío', (tester) async {
    await tester.pumpWidget(host(<QuickReply>[_qr(deleted: true)]));
    await openSheet(tester);

    expect(find.byKey(const Key('quick_replies_sheet.empty')), findsOneWidget);
  });

  testWidgets('catálogo vacío → copy de vacío', (tester) async {
    await tester.pumpWidget(host(<QuickReply>[]));
    await openSheet(tester);
    expect(find.byKey(const Key('quick_replies_sheet.empty')), findsOneWidget);
  });

  testWidgets('tocar una respuesta cierra el sheet devolviendo su message', (
    tester,
  ) async {
    String? result;
    var called = false;
    await tester.pumpWidget(
      host(
        <QuickReply>[
          _qr(shortcut: 'saludo', message: 'Hola, ¿en qué te ayudo?'),
        ],
        onResult: (r) {
          result = r;
          called = true;
        },
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text('saludo'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, 'Hola, ¿en qué te ayudo?');
    // El sheet se cerró.
    expect(find.byKey(const Key('quick_replies_sheet')), findsNothing);
  });
}
