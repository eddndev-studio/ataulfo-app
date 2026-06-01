import 'dart:async';

import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements WaLabelsRepository {}

WaLabel _label({
  String id = '1000',
  String name = 'VIP',
  int color = 3,
  bool deleted = false,
}) => WaLabel(waLabelId: id, name: name, color: color, deleted: deleted);

void main() {
  late _MockRepo repo;
  late StreamController<WaLabelLiveEvent> live;

  setUp(() {
    repo = _MockRepo();
    live = StreamController<WaLabelLiveEvent>.broadcast();
    when(
      () => repo.liveEvents(any()),
    ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
  });

  tearDown(() => live.close());

  WaLabelsBloc build() => WaLabelsBloc(repo: repo, botId: 'b1');

  group('carga inicial', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'load → Loaded con el catálogo (incluye tombstones)',
      build: () {
        when(() => repo.listCatalog('b1')).thenAnswer(
          (_) async => <WaLabel>[_label(), _label(id: '1001', deleted: true)],
        );
        return build();
      },
      act: (b) => b.add(const WaLabelsLoadRequested()),
      expect: () => <WaLabelsState>[
        WaLabelsLoaded(
          labels: <WaLabel>[
            _label(),
            _label(id: '1001', deleted: true),
          ],
          isRefreshing: false,
        ),
      ],
    );

    blocTest<WaLabelsBloc, WaLabelsState>(
      'load failure → Failed',
      build: () {
        when(
          () => repo.listCatalog('b1'),
        ).thenThrow(const WaLabelsForbiddenFailure());
        return build();
      },
      act: (b) => b.add(const WaLabelsLoadRequested()),
      expect: () => <WaLabelsState>[
        const WaLabelsFailed(WaLabelsForbiddenFailure()),
      ],
    );
  });

  group('realtime label.wa.* (catálogo)', () {
    test('EDITED de etiqueta existente → la actualiza en sitio', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => <WaLabel>[_label(name: 'VIP', color: 3)]);
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaLabelsLoadRequested());

      await bloc.stream.firstWhere((s) => s is WaLabelsLoaded);
      live.add(
        const WaLabelCatalogChanged(
          waLabelId: '1000',
          name: 'VIP Oro',
          color: 5,
          removed: false,
        ),
      );

      final next = await bloc.stream.firstWhere(
        (s) => s is WaLabelsLoaded && s.labels.first.name == 'VIP Oro',
      );
      final loaded = next as WaLabelsLoaded;
      expect(loaded.labels, hasLength(1));
      expect(loaded.labels.first.color, 5);
      await bloc.close();
    });

    test('EDITED de etiqueta nueva → la inserta', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => <WaLabel>[_label()]);
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaLabelsLoadRequested());
      await bloc.stream.firstWhere((s) => s is WaLabelsLoaded);

      live.add(
        const WaLabelCatalogChanged(
          waLabelId: '1002',
          name: 'Nueva',
          color: 7,
          removed: false,
        ),
      );

      final next =
          await bloc.stream.firstWhere(
                (s) => s is WaLabelsLoaded && s.labels.length == 2,
              )
              as WaLabelsLoaded;
      expect(next.labels.last.waLabelId, '1002');
      await bloc.close();
    });

    test('REMOVED → marca deleted y PRESERVA name/color del espejo', () async {
      // El espejo del backend conserva la identidad (name/color) en el
      // tombstone; el evento REMOVED puede traer name vacío. El cliente no debe
      // blanquear el name al marcar el tombstone.
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => <WaLabel>[_label(name: 'VIP', color: 7)]);
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaLabelsLoadRequested());
      await bloc.stream.firstWhere((s) => s is WaLabelsLoaded);

      live.add(
        const WaLabelCatalogChanged(
          waLabelId: '1000',
          name: '',
          color: 7,
          removed: true,
        ),
      );

      final next =
          await bloc.stream.firstWhere(
                (s) => s is WaLabelsLoaded && s.labels.first.deleted,
              )
              as WaLabelsLoaded;
      expect(next.labels.first.deleted, isTrue);
      expect(next.labels.first.name, 'VIP'); // no se blanquea
      expect(next.labels.first.color, 7);
      await bloc.close();
    });

    test('eventos CHAT/MESSAGE se ignoran (no cambian el catálogo)', () async {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => <WaLabel>[_label()]);
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaLabelsLoadRequested());
      final loaded = await bloc.stream.firstWhere((s) => s is WaLabelsLoaded);

      final states = <WaLabelsState>[];
      final sub = bloc.stream.listen(states.add);
      live.add(
        const WaChatLabelChanged(
          waLabelId: '1000',
          chatLid: 'c1',
          color: 3,
          labeled: true,
        ),
      );
      live.add(
        const WaMessageLabelChanged(
          waLabelId: '1000',
          chatLid: 'c1',
          messageId: 'wamid.1',
          color: 3,
          labeled: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(states, isEmpty); // ningún re-emit
      expect((loaded as WaLabelsLoaded).labels, hasLength(1));
      await sub.cancel();
      await bloc.close();
    });

    test('reconexión → refetch del catálogo', () async {
      var calls = 0;
      when(() => repo.listCatalog('b1')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? <WaLabel>[_label()]
            : <WaLabel>[_label(), _label(id: '1003', name: 'Tras corte')];
      });
      when(() => repo.liveEvents('b1')).thenAnswer((_) => live.stream);
      final bloc = build()..add(const WaLabelsLoadRequested());
      await bloc.stream.firstWhere((s) => s is WaLabelsLoaded);

      live.add(const WaLabelReconnected());

      final next =
          await bloc.stream.firstWhere(
                (s) => s is WaLabelsLoaded && s.labels.length == 2,
              )
              as WaLabelsLoaded;
      expect(next.labels.last.name, 'Tras corte');
      expect(calls, 2);
      await bloc.close();
    });
  });

  group('refresh', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'refresh desde Loaded → isRefreshing true luego lista nueva',
      build: () {
        var calls = 0;
        when(() => repo.listCatalog('b1')).thenAnswer((_) async {
          calls++;
          return calls == 1
              ? <WaLabel>[_label()]
              : <WaLabel>[_label(), _label(id: '1004', name: 'Extra')];
        });
        return build();
      },
      act: (b) async {
        b.add(const WaLabelsLoadRequested());
        await b.stream.firstWhere((s) => s is WaLabelsLoaded);
        b.add(const WaLabelsRefreshRequested());
      },
      expect: () => <WaLabelsState>[
        WaLabelsLoaded(labels: <WaLabel>[_label()], isRefreshing: false),
        WaLabelsLoaded(labels: <WaLabel>[_label()], isRefreshing: true),
        WaLabelsLoaded(
          labels: <WaLabel>[
            _label(),
            _label(id: '1004', name: 'Extra'),
          ],
          isRefreshing: false,
        ),
      ],
    );
  });
}
