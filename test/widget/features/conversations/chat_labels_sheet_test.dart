import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/presentation/widgets/chat_labels_sheet.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/chat_labels_bloc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_chat_labels_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChat extends Mock implements ChatLabelsRepository {}

class _MockWa extends Mock implements WaLabelsRepository {}

Label _l(String id, String name) =>
    Label(id: id, name: name, color: '#FF8800', description: '');

void main() {
  late _MockChat chat;
  late _MockWa wa;

  setUp(() {
    chat = _MockChat();
    wa = _MockWa();

    // Aplicadas al chat: VIP (mapeada a WA) + Cliente nuevo (no mapeada).
    when(() => chat.listForChat('bot', 'chat')).thenAnswer(
      (_) async => <Label>[_l('a', 'VIP'), _l('b', 'Cliente nuevo')],
    );

    when(() => wa.listCatalog('bot')).thenAnswer(
      (_) async => <WaLabel>[
        const WaLabel(
          waLabelId: 'w1',
          name: 'Pagado',
          color: 2,
          deleted: false,
        ),
      ],
    );
    when(
      () => wa.listChatAssocs('bot'),
    ).thenAnswer((_) async => <WaChatAssoc>[]);
    when(
      () => wa.liveEvents('bot'),
    ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<ChatLabelsBloc>(
            create: (_) => ChatLabelsBloc(
              chatRepo: chat,
              botId: 'bot',
              chatLid: 'chat',
              loadMappedLabelIds: () async => <String>{'a'},
            )..add(const ChatLabelsLoadRequested()),
          ),
          BlocProvider<WaChatLabelsBloc>(
            create: (_) => WaChatLabelsBloc(
              repo: wa,
              botId: 'bot',
              chatLid: 'chat',
              kind: ConversationKind.dm,
            )..add(const WaChatLabelsLoadRequested()),
          ),
        ],
        child: const ChatLabelsSheet(),
      ),
    ),
  );

  testWidgets('pinta ambas secciones con sus etiquetas', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('INTERNAS'), findsOneWidget);
    expect(find.text('WHATSAPP'), findsOneWidget);
    // Internas (solo lectura): muestra las APLICADAS al chat.
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Cliente nuevo'), findsOneWidget);
    // WhatsApp: catálogo activo del bot.
    expect(find.text('Pagado'), findsOneWidget);
  });

  testWidgets('una etiqueta interna mapeada se anota "también en WhatsApp"', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    // VIP (id 'a') está en mapped → lleva la anotación; Cliente nuevo no.
    expect(find.text('también en WhatsApp'), findsOneWidget);
  });

  testWidgets('sin etiquetas internas aplicadas muestra el vacío', (
    tester,
  ) async {
    when(
      () => chat.listForChat('bot', 'chat'),
    ).thenAnswer((_) async => <Label>[]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Este chat no tiene etiquetas internas.'), findsOneWidget);
  });
}
