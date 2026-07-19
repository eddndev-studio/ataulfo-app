import 'dart:convert';

import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/presentation/widgets/pa_message_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/chat_media_providers.dart';

/// Construye el `tool_results` tal como llega del wire: jsonb crudo con claves
/// snake_case y `content` DOBLE-CODIFICADO (string JSON del output del tool).
String _toolRaw(String toolName, Map<String, dynamic> content) =>
    jsonEncode(<String, dynamic>{
      'tool_call_id': 'tc1',
      'tool_name': toolName,
      'content': jsonEncode(content),
    });

PaMessage _toolMsg(String raw) => PaMessage(
  id: 'm1',
  conversationId: 'c1',
  role: 'tool',
  content: '',
  createdAt: DateTime.utc(2026, 6, 10),
  toolResultsRaw: raw,
);

PaMessage _textMsg(String role, String content) => PaMessage(
  id: 'm1',
  conversationId: 'c1',
  role: role,
  content: content,
  createdAt: DateTime.utc(2026, 6, 10),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: wrapWithChatMedia(child))),
);

void main() {
  testWidgets('lee el nombre del tool de tool_name (snake_case del wire)', (
    tester,
  ) async {
    // Sin detalle estructurado: chip plano, no expandible. Prueba el fix del
    // bug latente (leer tool_name, no toolName) — antes decía "Acción ejecutada".
    final raw = _toolRaw('list_bots', <String, dynamic>{'bots': <dynamic>[]});
    await tester.pumpWidget(_wrap(PaMessageTile(message: _toolMsg(raw))));
    expect(find.text('Consultó los Canales'), findsOneWidget);
    expect(find.byKey(const Key('pa.tool_card.header')), findsNothing);
  });

  testWidgets('changeset: colapsado oculta el detalle; al tocar lo expande', (
    tester,
  ) async {
    final raw = _toolRaw('update_flow', <String, dynamic>{
      'changed': <dynamic>[
        <String, dynamic>{'field': 'is_active', 'from': false, 'to': true},
      ],
    });
    await tester.pumpWidget(_wrap(PaMessageTile(message: _toolMsg(raw))));

    expect(find.text('Actualizó un flujo'), findsOneWidget);
    // Colapsado: el campo cambiado no está visible.
    expect(find.textContaining('is_active'), findsNothing);

    await tester.tap(find.byKey(const Key('pa.tool_card.header')));
    await tester.pumpAndSettle();

    expect(find.textContaining('is_active'), findsOneWidget);
    expect(find.textContaining('true'), findsWidgets);
  });

  testWidgets('error_kind se traduce a español en el detalle', (tester) async {
    final raw = _toolRaw('update_variable', <String, dynamic>{
      'error_kind': 'variable_in_use',
      'var_def_id': 'v1',
    });
    await tester.pumpWidget(_wrap(PaMessageTile(message: _toolMsg(raw))));

    expect(find.text('Actualizó una variable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pa.tool_card.header')));
    await tester.pumpAndSettle();

    expect(find.textContaining('en uso'), findsOneWidget);
  });

  testWidgets('resultado sin shape esperado degrada a chip plano', (
    tester,
  ) async {
    final raw = jsonEncode(<String, dynamic>{
      'tool_call_id': 'tc1',
      'tool_name': 'react',
      'content': 'no-json',
    });
    await tester.pumpWidget(_wrap(PaMessageTile(message: _toolMsg(raw))));
    expect(find.text('Usó react'), findsOneWidget);
    expect(find.byKey(const Key('pa.tool_card.header')), findsNothing);
  });

  testWidgets('edit_doc muestra nombre, contexto y reemplazo anclado', (
    tester,
  ) async {
    final raw = _toolRaw('edit_doc', <String, dynamic>{
      'name': 'politica-devoluciones.md',
      'diff': <String, dynamic>{
        'old': 'Aceptamos devoluciones durante 15 días.',
        'new': 'Aceptamos devoluciones durante 30 días.',
        'context': 'Política de cambios y devoluciones',
      },
    });
    await tester.pumpWidget(_wrap(PaMessageTile(message: _toolMsg(raw))));

    expect(
      find.text('Documento actualizado · politica-devoluciones.md'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pa.tool_card.header')));
    await tester.pumpAndSettle();

    expect(find.text('Política de cambios y devoluciones'), findsOneWidget);
    expect(
      find.text('− Aceptamos devoluciones durante 15 días.'),
      findsOneWidget,
    );
    expect(
      find.text('+ Aceptamos devoluciones durante 30 días.'),
      findsOneWidget,
    );
  });

  String confirmRaw() => _toolRaw('update_template', <String, dynamic>{
    'error_kind': 'requires_confirmation',
    'affected_bots': 2,
    'bots': <dynamic>[
      <String, dynamic>{'id': 'b1', 'name': 'Ventas'},
      <String, dynamic>{'id': 'b2', 'name': 'Soporte'},
    ],
  });

  testWidgets(
    'requires_confirmation: nombra los bots y ofrece Confirmar/Cancelar',
    (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        _wrap(
          PaMessageTile(
            message: _toolMsg(confirmRaw()),
            onConfirm: () => confirmed = true,
          ),
        ),
      );
      expect(find.textContaining('Ventas'), findsOneWidget);
      expect(find.textContaining('Soporte'), findsOneWidget);
      expect(find.byKey(const Key('pa.confirm.accept')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pa.confirm.accept')));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      // Tras actuar, los botones desaparecen (no doble-confirmación).
      expect(find.byKey(const Key('pa.confirm.accept')), findsNothing);
    },
  );

  testWidgets(
    'requires_confirmation: Cancelar no confirma y retira los botones',
    (tester) async {
      var confirmed = false;
      await tester.pumpWidget(
        _wrap(
          PaMessageTile(
            message: _toolMsg(confirmRaw()),
            onConfirm: () => confirmed = true,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('pa.confirm.cancel')));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse);
      expect(find.byKey(const Key('pa.confirm.accept')), findsNothing);
    },
  );

  testWidgets(
    'requires_confirmation sin onConfirm degrada a tarjeta de error',
    (tester) async {
      await tester.pumpWidget(
        _wrap(PaMessageTile(message: _toolMsg(confirmRaw()))),
      );
      // Sin callback no hay botones: cae a la tarjeta expandible genérica.
      expect(find.byKey(const Key('pa.confirm.accept')), findsNothing);
      await tester.tap(find.byKey(const Key('pa.tool_card.header')));
      await tester.pumpAndSettle();
      expect(find.textContaining('confirmaci'), findsOneWidget);
    },
  );

  testWidgets('long-press en burbuja de assistant copia el contenido', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      _wrap(PaMessageTile(message: _textMsg('assistant', 'respuesta del bot'))),
    );
    await tester.longPress(find.byType(AssistantMarkdown));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy.pa.m1.copy')));
    await tester.pumpAndSettle();
    expect(copied, <String>['respuesta del bot']);
  });

  testWidgets('la tarjeta de tool NO es copiable (long-press no abre hoja)', (
    tester,
  ) async {
    final raw = _toolRaw('list_bots', <String, dynamic>{'bots': <dynamic>[]});
    await tester.pumpWidget(_wrap(PaMessageTile(message: _toolMsg(raw))));
    await tester.longPress(find.text('Consultó los Canales'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('copy.pa.m1.copy')), findsNothing);
  });

  testWidgets('assistant rinde Markdown; user queda en Text plano', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(PaMessageTile(message: _textMsg('assistant', '**negrita**'))),
    );
    expect(find.byType(AssistantMarkdown), findsOneWidget);

    await tester.pumpWidget(
      _wrap(PaMessageTile(message: _textMsg('user', '**negrita**'))),
    );
    expect(find.byType(AssistantMarkdown), findsNothing);
    expect(find.text('**negrita**'), findsOneWidget);
  });

  testWidgets('nota de voz con transcripción: "Nota de voz" + el transcrito, '
      'sin filtrar el marcador crudo', (tester) async {
    const marker = '[audio recibido, sin transcripción]';
    final voice = PaMessage(
      id: 'v1',
      conversationId: 'c1',
      role: 'user',
      content: 'agenda una demo para el martes',
      audioRef: 'tenant/org/media/v1.ogg',
      transcriptStatus: 'done',
      transcript: 'agenda una demo para el martes',
      createdAt: DateTime.utc(2026, 6, 10),
    );
    await tester.pumpWidget(_wrap(PaMessageTile(message: voice)));
    expect(find.text('Nota de voz'), findsOneWidget);
    expect(find.text('agenda una demo para el martes'), findsOneWidget);
    expect(find.text(marker), findsNothing);
  });

  testWidgets('nota de voz sin transcripción: solo "Nota de voz", nunca el '
      'marcador crudo', (tester) async {
    const marker = '[audio recibido, sin transcripción]';
    final voice = PaMessage(
      id: 'v2',
      conversationId: 'c1',
      role: 'user',
      content: marker,
      audioRef: 'tenant/org/media/v2.ogg',
      transcriptStatus: 'unavailable',
      createdAt: DateTime.utc(2026, 6, 10),
    );
    await tester.pumpWidget(_wrap(PaMessageTile(message: voice)));
    expect(find.text('Nota de voz'), findsOneWidget);
    expect(find.text(marker), findsNothing);
  });
}
