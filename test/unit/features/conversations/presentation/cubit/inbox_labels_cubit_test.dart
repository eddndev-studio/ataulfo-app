import 'dart:async';

import 'package:ataulfo/features/conversations/presentation/cubit/inbox_labels_cubit.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
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
    when(
      () => repo.listCatalog('b1'),
    ).thenAnswer((_) async => const <WaLabel>[_a, _b, _c]);
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

  test(
    'degrada a vacío si falla el catálogo (las etiquetas son mejora)',
    () async {
      when(() => repo.listCatalog('b1')).thenThrow(Exception('boom'));
      when(
        () => repo.listChatAssocs('b1'),
      ).thenAnswer((_) async => const <WaChatAssoc>[]);

      final cubit = build();
      await cubit.load();

      expect(cubit.state.catalog, isEmpty);
      expect(cubit.state.byChat, isEmpty);
      addTearDown(cubit.close);
    },
  );

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

  group('watchLive (bandeja reactiva)', () {
    late StreamController<WaLabelLiveEvent> live;

    setUp(() {
      live = StreamController<WaLabelLiveEvent>.broadcast();
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
    });

    // Deja correr la entrega asíncrona del stream + cualquier load() disparado.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('un WaChatLabelChanged etiqueta el chat sin recargar', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => const <WaLabel>[_a, _b]);
      when(
        () => repo.listChatAssocs('b1'),
      ).thenAnswer((_) async => const <WaChatAssoc>[]);

      final cubit = build();
      await cubit.watchLive();
      addTearDown(cubit.close);
      addTearDown(live.close);

      live.add(
        const WaChatLabelChanged(
          waLabelId: 'A',
          chatLid: 'chat-9',
          color: 0,
          labeled: true,
        ),
      );
      await settle();

      expect(cubit.state.byChat['chat-9'], const <WaLabel>[_a]);
      // No hubo segunda carga: el delta se aplicó en memoria.
      verify(() => repo.listCatalog('b1')).called(1);
    });

    test('un WaChatLabelChanged con labeled:false desasocia', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => const <WaLabel>[_a]);
      when(() => repo.listChatAssocs('b1')).thenAnswer(
        (_) async => const <WaChatAssoc>[
          WaChatAssoc(chatLid: 'chat-1', waLabelId: 'A', labeled: true),
        ],
      );

      final cubit = build();
      await cubit.watchLive();
      addTearDown(cubit.close);
      addTearDown(live.close);
      expect(cubit.state.byChat['chat-1'], const <WaLabel>[_a]);

      live.add(
        const WaChatLabelChanged(
          waLabelId: 'A',
          chatLid: 'chat-1',
          color: 0,
          labeled: false,
        ),
      );
      await settle();

      expect(cubit.state.byChat.containsKey('chat-1'), isFalse);
    });

    test('ignora un delta de etiqueta ausente del catálogo', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => const <WaLabel>[_a]);
      when(
        () => repo.listChatAssocs('b1'),
      ).thenAnswer((_) async => const <WaChatAssoc>[]);

      final cubit = build();
      await cubit.watchLive();
      addTearDown(cubit.close);
      addTearDown(live.close);

      live.add(
        const WaChatLabelChanged(
          waLabelId: 'Z',
          chatLid: 'chat-1',
          color: 0,
          labeled: true,
        ),
      );
      await settle();

      expect(cubit.state.byChat, isEmpty);
    });

    test('recarga (reconcilia) ante WaLabelReconnected', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => const <WaLabel>[_a]);
      when(
        () => repo.listChatAssocs('b1'),
      ).thenAnswer((_) async => const <WaChatAssoc>[]);

      final cubit = build();
      await cubit.watchLive();
      addTearDown(cubit.close);
      addTearDown(live.close);

      live.add(const WaLabelReconnected());
      await settle();

      // Carga inicial (watchLive) + reconciliación tras reconectar.
      verify(() => repo.listCatalog('b1')).called(2);
    });
  });

  test(
    'close durante la carga inicial no abre la suscripción en vivo (sin fuga)',
    () async {
      // La carga inicial de watchLive queda en vuelo mientras el operador se
      // va (pop de la ruta → close()). Al resolverse la carga, _startLive NO
      // debe suscribirse: sería un SSE que reconecta para siempre sobre un
      // cubit ya muerto (el cancel de close() ya corrió con _liveSub en null).
      final catalogGate = Completer<List<WaLabel>>();
      when(() => repo.listCatalog('b1')).thenAnswer((_) => catalogGate.future);
      when(
        () => repo.listChatAssocs('b1'),
      ).thenAnswer((_) async => const <WaChatAssoc>[]);
      when(
        () => repo.liveEvents('b1'),
      ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());

      final cubit = build();
      final watching = cubit.watchLive(); // sin await: queda en `await load()`
      await Future<void>.delayed(Duration.zero); // deja entrar a load()

      await cubit.close(); // el operador abandona la bandeja durante la carga
      catalogGate.complete(const <WaLabel>[_a]); // load() resuelve tras close
      await watching; // corre la continuación (…_startLive())
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repo.liveEvents('b1'));
    },
  );
}
