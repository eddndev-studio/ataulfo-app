import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/wa_labels/presentation/bloc/wa_labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements WaLabelsRepository {}

WaLabel _l({
  String id = '1000',
  String name = 'VIP',
  int color = 3,
  bool deleted = false,
}) => WaLabel(waLabelId: id, name: name, color: color, deleted: deleted);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.liveEvents(any()),
    ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
  });

  WaLabelsBloc build() => WaLabelsBloc(repo: repo, botId: 'b1');

  final loaded = WaLabelsLoaded(labels: <WaLabel>[_l()], isRefreshing: false);

  group('crear', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'éxito → Mutating(snapshot) luego Loaded con la nueva (optimista)',
      build: () {
        when(
          () => repo.createLabel(botId: 'b1', name: 'Nueva', color: 7),
        ).thenAnswer((_) async => _l(id: '1001', name: 'Nueva', color: 7));
        return build();
      },
      seed: () => loaded,
      act: (b) => b.add(const WaLabelsAddRequested(name: 'Nueva', color: 7)),
      expect: () => <WaLabelsState>[
        WaLabelsMutating(<WaLabel>[_l()]),
        WaLabelsLoaded(
          labels: <WaLabel>[
            _l(),
            _l(id: '1001', name: 'Nueva', color: 7),
          ],
          isRefreshing: false,
        ),
      ],
    );

    blocTest<WaLabelsBloc, WaLabelsState>(
      '409 NotConnected → MutationFailed(snapshot) preserva la lista',
      build: () {
        when(
          () => repo.createLabel(
            botId: any(named: 'botId'),
            name: any(named: 'name'),
            color: any(named: 'color'),
          ),
        ).thenThrow(const WaLabelsNotConnectedFailure());
        return build();
      },
      seed: () => loaded,
      act: (b) => b.add(const WaLabelsAddRequested(name: 'X', color: 1)),
      expect: () => <WaLabelsState>[
        WaLabelsMutating(<WaLabel>[_l()]),
        WaLabelsMutationFailed(<WaLabel>[
          _l(),
        ], const WaLabelsNotConnectedFailure()),
      ],
    );
  });

  group('editar', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'éxito → upsert en sitio de la etiqueta editada',
      build: () {
        when(
          () => repo.updateLabel(
            botId: 'b1',
            waLabelId: '1000',
            name: 'VIP Oro',
            color: 5,
          ),
        ).thenAnswer((_) async => _l(name: 'VIP Oro', color: 5));
        return build();
      },
      seed: () => loaded,
      act: (b) => b.add(
        const WaLabelsUpdateRequested(
          waLabelId: '1000',
          name: 'VIP Oro',
          color: 5,
        ),
      ),
      expect: () => <WaLabelsState>[
        WaLabelsMutating(<WaLabel>[_l()]),
        WaLabelsLoaded(
          labels: <WaLabel>[_l(name: 'VIP Oro', color: 5)],
          isRefreshing: false,
        ),
      ],
    );
  });

  group('borrar', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'éxito → marca tombstone optimista (la lista conserva la entrada)',
      build: () {
        when(
          () => repo.deleteLabel(botId: 'b1', waLabelId: '1000'),
        ).thenAnswer((_) async {});
        return build();
      },
      seed: () => loaded,
      act: (b) => b.add(const WaLabelsDeleteRequested(waLabelId: '1000')),
      expect: () => <WaLabelsState>[
        WaLabelsMutating(<WaLabel>[_l()]),
        WaLabelsLoaded(
          labels: <WaLabel>[_l(deleted: true)],
          isRefreshing: false,
        ),
      ],
    );

    blocTest<WaLabelsBloc, WaLabelsState>(
      '502 Upstream → MutationFailed',
      build: () {
        when(
          () => repo.deleteLabel(
            botId: any(named: 'botId'),
            waLabelId: any(named: 'waLabelId'),
          ),
        ).thenThrow(const WaLabelsUpstreamFailure());
        return build();
      },
      seed: () => loaded,
      act: (b) => b.add(const WaLabelsDeleteRequested(waLabelId: '1000')),
      expect: () => <WaLabelsState>[
        WaLabelsMutating(<WaLabel>[_l()]),
        WaLabelsMutationFailed(<WaLabel>[
          _l(),
        ], const WaLabelsUpstreamFailure()),
      ],
    );
  });

  group('realtime sigue vivo desde MutationFailed (no se congela)', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'un cambio live parchea el snapshot pero conserva la variante/failure',
      build: build,
      seed: () => WaLabelsMutationFailed(<WaLabel>[
        _l(),
      ], const WaLabelsUpstreamFailure()),
      act: (b) => b.add(
        const WaLabelsCatalogChanged(
          WaLabelCatalogChanged(
            waLabelId: '1002',
            name: 'Live',
            color: 9,
            removed: false,
          ),
        ),
      ),
      expect: () => <WaLabelsState>[
        WaLabelsMutationFailed(<WaLabel>[
          _l(),
          _l(id: '1002', name: 'Live', color: 9),
        ], const WaLabelsUpstreamFailure()),
      ],
    );

    blocTest<WaLabelsBloc, WaLabelsState>(
      'reconexión refetcha incluso desde MutationFailed (conserva failure)',
      build: () {
        when(() => repo.listCatalog('b1')).thenAnswer(
          (_) async => <WaLabel>[_l(), _l(id: '1003', name: 'Refetch')],
        );
        return build();
      },
      seed: () => WaLabelsMutationFailed(<WaLabel>[
        _l(),
      ], const WaLabelsNotConnectedFailure()),
      act: (b) => b.add(const WaLabelsReconnected()),
      expect: () => <WaLabelsState>[
        WaLabelsMutationFailed(<WaLabel>[
          _l(),
          _l(id: '1003', name: 'Refetch'),
        ], const WaLabelsNotConnectedFailure()),
      ],
    );
  });

  group('reusar snapshot / ignorar', () {
    blocTest<WaLabelsBloc, WaLabelsState>(
      'mutación desde Loading se ignora (sin snapshot fiable)',
      build: build,
      act: (b) => b.add(const WaLabelsAddRequested(name: 'X', color: 1)),
      expect: () => <WaLabelsState>[],
    );

    blocTest<WaLabelsBloc, WaLabelsState>(
      'una nueva mutación desde MutationFailed reusa su snapshot',
      build: () {
        when(
          () => repo.createLabel(botId: 'b1', name: 'Z', color: 2),
        ).thenAnswer((_) async => _l(id: '1009', name: 'Z', color: 2));
        return build();
      },
      seed: () => WaLabelsMutationFailed(<WaLabel>[
        _l(),
      ], const WaLabelsInvalidFailure()),
      act: (b) => b.add(const WaLabelsAddRequested(name: 'Z', color: 2)),
      expect: () => <WaLabelsState>[
        WaLabelsMutating(<WaLabel>[_l()]),
        WaLabelsLoaded(
          labels: <WaLabel>[
            _l(),
            _l(id: '1009', name: 'Z', color: 2),
          ],
          isRefreshing: false,
        ),
      ],
    );
  });
}
