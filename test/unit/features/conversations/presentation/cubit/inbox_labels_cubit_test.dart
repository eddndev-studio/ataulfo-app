import 'package:ataulfo/features/conversations/presentation/cubit/inbox_labels_cubit.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

const _a = WaLabel(waLabelId: 'A', name: 'VIP', color: 0, deleted: false);
const _b = WaLabel(waLabelId: 'B', name: 'Soporte', color: 3, deleted: false);
const _c = WaLabel(waLabelId: 'C', name: 'Viejo', color: 5, deleted: true);

void main() {
  late _MockWaLabelsRepo repo;

  setUp(() {
    repo = _MockWaLabelsRepo();
  });

  InboxLabelsCubit build() => InboxLabelsCubit(repo: repo, botId: 'b1');

  test('estado inicial: catálogo y mapa vacíos', () {
    expect(build().state.catalog, isEmpty);
    expect(build().state.byChat, isEmpty);
  });

  test('load compone catálogo (sin tombstones) y byChat por chat', () async {
    when(() => repo.listCatalog('b1')).thenAnswer(
      (_) async => const <WaLabel>[_a, _b, _c],
    );
    when(() => repo.listChatAssocs('b1')).thenAnswer(
      (_) async => const <WaChatAssoc>[
        WaChatAssoc(chatLid: 'chat-1', waLabelId: 'A', labeled: true),
        WaChatAssoc(chatLid: 'chat-1', waLabelId: 'B', labeled: true),
        WaChatAssoc(chatLid: 'chat-2', waLabelId: 'A', labeled: true),
      ],
    );

    final cubit = build();
    await cubit.load();

    // El catálogo excluye el tombstone (C).
    expect(cubit.state.catalog, const <WaLabel>[_a, _b]);
    // Cada chat resuelve sus etiquetas activas.
    expect(cubit.state.byChat['chat-1'], const <WaLabel>[_a, _b]);
    expect(cubit.state.byChat['chat-2'], const <WaLabel>[_a]);
    addTearDown(cubit.close);
  });

  test('ignora asociaciones con labeled:false (desasociadas)', () async {
    when(
      () => repo.listCatalog('b1'),
    ).thenAnswer((_) async => const <WaLabel>[_a]);
    when(() => repo.listChatAssocs('b1')).thenAnswer(
      (_) async => const <WaChatAssoc>[
        WaChatAssoc(chatLid: 'chat-1', waLabelId: 'A', labeled: false),
      ],
    );

    final cubit = build();
    await cubit.load();

    expect(cubit.state.byChat.containsKey('chat-1'), isFalse);
    addTearDown(cubit.close);
  });

  test('ignora asociaciones a una etiqueta borrada o inexistente', () async {
    when(
      () => repo.listCatalog('b1'),
    ).thenAnswer((_) async => const <WaLabel>[_a, _c]);
    when(() => repo.listChatAssocs('b1')).thenAnswer(
      (_) async => const <WaChatAssoc>[
        // C es tombstone (no entra al catálogo activo) → su assoc se ignora.
        WaChatAssoc(chatLid: 'chat-1', waLabelId: 'C', labeled: true),
        // Z no existe en el catálogo → se ignora sin crashear.
        WaChatAssoc(chatLid: 'chat-1', waLabelId: 'Z', labeled: true),
      ],
    );

    final cubit = build();
    await cubit.load();

    expect(cubit.state.byChat.containsKey('chat-1'), isFalse);
    addTearDown(cubit.close);
  });

  test('degrada a vacío si falla el catálogo (las etiquetas son mejora)', () async {
    when(() => repo.listCatalog('b1')).thenThrow(Exception('boom'));
    when(
      () => repo.listChatAssocs('b1'),
    ).thenAnswer((_) async => const <WaChatAssoc>[]);

    final cubit = build();
    await cubit.load();

    expect(cubit.state.catalog, isEmpty);
    expect(cubit.state.byChat, isEmpty);
    addTearDown(cubit.close);
  });

  test('degrada a vacío si fallan las asociaciones', () async {
    when(
      () => repo.listCatalog('b1'),
    ).thenAnswer((_) async => const <WaLabel>[_a]);
    when(() => repo.listChatAssocs('b1')).thenThrow(Exception('boom'));

    final cubit = build();
    await cubit.load();

    expect(cubit.state.catalog, isEmpty);
    expect(cubit.state.byChat, isEmpty);
    addTearDown(cubit.close);
  });
}
