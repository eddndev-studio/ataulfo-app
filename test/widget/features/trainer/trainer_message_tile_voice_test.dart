import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/presentation/widgets/trainer_message_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/chat_media_providers.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: wrapWithChatMedia(child))),
);

void main() {
  testWidgets('nota de voz con transcripción: "Nota de voz" + el transcrito, '
      'sin filtrar el marcador crudo', (tester) async {
    const marker = '[audio recibido, sin transcripción]';
    final voice = TrainerMessage(
      id: 'v1',
      conversationId: 'c1',
      role: 'user',
      content: 'mis tacos cuestan 25 pesos',
      audioRef: 'tenant/org/media/v1.ogg',
      transcriptStatus: 'done',
      transcript: 'mis tacos cuestan 25 pesos',
      createdAt: DateTime.utc(2026, 6, 10),
    );
    await tester.pumpWidget(_wrap(TrainerMessageTile(message: voice)));
    expect(find.text('Nota de voz'), findsOneWidget);
    expect(find.text('mis tacos cuestan 25 pesos'), findsOneWidget);
    expect(find.text(marker), findsNothing);
  });

  testWidgets('nota de voz sin transcripción: solo "Nota de voz", nunca el '
      'marcador crudo', (tester) async {
    const marker = '[audio recibido, sin transcripción]';
    final voice = TrainerMessage(
      id: 'v2',
      conversationId: 'c1',
      role: 'user',
      content: marker,
      audioRef: 'tenant/org/media/v2.ogg',
      transcriptStatus: 'unavailable',
      createdAt: DateTime.utc(2026, 6, 10),
    );
    await tester.pumpWidget(_wrap(TrainerMessageTile(message: voice)));
    expect(find.text('Nota de voz'), findsOneWidget);
    expect(find.text(marker), findsNothing);
  });
}
