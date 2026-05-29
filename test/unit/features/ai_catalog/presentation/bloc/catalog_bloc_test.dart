import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/failures/catalog_failure.dart';
import 'package:ataulfo/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:ataulfo/features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CatalogRepository {}

const _gemini = ProviderEntry(
  provider: 'GEMINI',
  defaultModel: 'gemini-3.1-pro-preview',
  models: <AIModel>[
    AIModel(
      id: 'gemini-3.1-pro-preview',
      supportsTemperature: true,
      supportsThinking: true,
    ),
  ],
);
const _openai = ProviderEntry(
  provider: 'OPENAI',
  defaultModel: 'gpt-5.5',
  models: <AIModel>[
    AIModel(id: 'gpt-5.5', supportsTemperature: false, supportsThinking: true),
  ],
);
const _catalog = Catalog(providers: <ProviderEntry>[_gemini, _openai]);

void main() {
  group('CatalogBloc', () {
    test('estado inicial = CatalogInitial', () {
      final bloc = CatalogBloc(_MockRepo());
      expect(bloc.state, const CatalogInitial());
    });

    group('CatalogLoadRequested', () {
      blocTest<CatalogBloc, CatalogState>(
        'fetch() ok → [Loading, Loaded(catalog)]',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer((_) async => _catalog);
          return CatalogBloc(repo);
        },
        act: (bloc) => bloc.add(const CatalogLoadRequested()),
        expect: () => const <CatalogState>[
          CatalogLoading(),
          CatalogLoaded(catalog: _catalog),
        ],
      );

      blocTest<CatalogBloc, CatalogState>(
        'forbidden → [Loading, Failed(Forbidden)]',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer(
            (_) => Future<Catalog>.error(const CatalogForbiddenFailure()),
          );
          return CatalogBloc(repo);
        },
        act: (bloc) => bloc.add(const CatalogLoadRequested()),
        expect: () => const <CatalogState>[
          CatalogLoading(),
          CatalogFailed(CatalogForbiddenFailure()),
        ],
      );

      blocTest<CatalogBloc, CatalogState>(
        'network → [Loading, Failed(Network)]',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer(
            (_) => Future<Catalog>.error(const CatalogNetworkFailure()),
          );
          return CatalogBloc(repo);
        },
        act: (bloc) => bloc.add(const CatalogLoadRequested()),
        expect: () => const <CatalogState>[
          CatalogLoading(),
          CatalogFailed(CatalogNetworkFailure()),
        ],
      );

      blocTest<CatalogBloc, CatalogState>(
        'retry desde Failed re-emite Loading visible',
        build: () {
          final repo = _MockRepo();
          when(repo.fetch).thenAnswer((_) async => _catalog);
          return CatalogBloc(repo);
        },
        // El primer load lo emite el caller; este test simula el segundo
        // (retry tras Failed) reusando LoadRequested.
        seed: () => const CatalogFailed(CatalogNetworkFailure()),
        act: (bloc) => bloc.add(const CatalogLoadRequested()),
        expect: () => const <CatalogState>[
          CatalogLoading(),
          CatalogLoaded(catalog: _catalog),
        ],
      );
    });
  });
}
