import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/chat_labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChat extends Mock implements ChatLabelsRepository {}

Label _l(String id, {String name = 'n'}) =>
    Label(id: id, name: name, color: '#FF8800', description: '');

void main() {
  late _MockChat chat;

  setUp(() {
    chat = _MockChat();
  });

  final applied = <Label>[_l('a', name: 'VIP'), _l('b', name: 'Nuevo')];

  ChatLabelsBloc build({Future<Set<String>> Function()? mapped}) =>
      ChatLabelsBloc(
        chatRepo: chat,
        botId: 'bot',
        chatLid: 'chat',
        loadMappedLabelIds: mapped,
      );

  test('estado inicial es ChatLabelsLoading', () {
    when(
      () => chat.listForChat('bot', 'chat'),
    ).thenAnswer((_) async => <Label>[]);
    expect(build().state, const ChatLabelsLoading());
  });

  blocTest<ChatLabelsBloc, ChatLabelsState>(
    'load: etiquetas aplicadas + mapeadas → Loaded',
    setUp: () {
      when(
        () => chat.listForChat('bot', 'chat'),
      ).thenAnswer((_) async => applied);
    },
    build: () => build(mapped: () async => <String>{'a'}),
    act: (b) => b.add(const ChatLabelsLoadRequested()),
    expect: () => <ChatLabelsState>[
      ChatLabelsLoaded(applied: applied, mapped: const <String>{'a'}),
    ],
  );

  blocTest<ChatLabelsBloc, ChatLabelsState>(
    'load: mapped es best-effort — si falla, Loaded con mapped vacío',
    setUp: () {
      when(
        () => chat.listForChat('bot', 'chat'),
      ).thenAnswer((_) async => applied);
    },
    build: () => build(mapped: () async => throw Exception('wa caído')),
    act: (b) => b.add(const ChatLabelsLoadRequested()),
    expect: () => <ChatLabelsState>[
      ChatLabelsLoaded(applied: applied, mapped: const <String>{}),
    ],
  );

  blocTest<ChatLabelsBloc, ChatLabelsState>(
    'load: listForChat falla → ChatLabelsFailed',
    setUp: () {
      when(
        () => chat.listForChat('bot', 'chat'),
      ).thenThrow(const LabelsForbiddenFailure());
    },
    build: build,
    act: (b) => b.add(const ChatLabelsLoadRequested()),
    expect: () => <ChatLabelsState>[
      const ChatLabelsFailed(LabelsForbiddenFailure()),
    ],
  );
}
