import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/domain/repositories/bots_repository.dart';
import 'package:agentic/features/bots/presentation/bloc/bot_create_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BotsRepository {}

const _bot = Bot(
  id: 'b9',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 0,
  paused: false,
  aiDisabled: false,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('BotCreateBloc', () {
    test('estado inicial = BotCreateInitial', () {
      final bloc = BotCreateBloc(repo: repo);
      expect(bloc.state, const BotCreateInitial());
      bloc.close();
    });

    blocTest<BotCreateBloc, BotCreateState>(
      'Submitted ok → [Submitting, Succeeded(bot)]',
      build: () {
        when(
          () => repo.create(
            templateId: 't1',
            name: 'Soporte',
            channel: BotChannel.waUnofficial,
          ),
        ).thenAnswer((_) async => _bot);
        return BotCreateBloc(repo: repo);
      },
      act: (bloc) => bloc.add(
        const BotCreateSubmitted(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
      ),
      expect: () => const <BotCreateState>[
        BotCreateSubmitting(),
        BotCreateSucceeded(_bot),
      ],
      verify: (_) => verify(
        () => repo.create(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
      ).called(1),
    );

    blocTest<BotCreateBloc, BotCreateState>(
      '422 → [Submitting, Failed(InvalidCreate)]',
      build: () {
        when(
          () => repo.create(
            templateId: 't1',
            name: '',
            channel: BotChannel.waUnofficial,
          ),
        ).thenAnswer(
          (_) => Future<Bot>.error(const BotsInvalidCreateFailure()),
        );
        return BotCreateBloc(repo: repo);
      },
      act: (bloc) => bloc.add(
        const BotCreateSubmitted(
          templateId: 't1',
          name: '',
          channel: BotChannel.waUnofficial,
        ),
      ),
      expect: () => const <BotCreateState>[
        BotCreateSubmitting(),
        BotCreateFailed(BotsInvalidCreateFailure()),
      ],
    );

    blocTest<BotCreateBloc, BotCreateState>(
      '403 → [Submitting, Failed(Forbidden)]',
      build: () {
        when(
          () => repo.create(
            templateId: 't1',
            name: 'Soporte',
            channel: BotChannel.waUnofficial,
          ),
        ).thenAnswer((_) => Future<Bot>.error(const BotsForbiddenFailure()));
        return BotCreateBloc(repo: repo);
      },
      act: (bloc) => bloc.add(
        const BotCreateSubmitted(
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
        ),
      ),
      expect: () => const <BotCreateState>[
        BotCreateSubmitting(),
        BotCreateFailed(BotsForbiddenFailure()),
      ],
    );

    blocTest<BotCreateBloc, BotCreateState>(
      'retry desde Failed: Submitted vuelve a pasar por Submitting',
      build: () {
        var calls = 0;
        when(
          () => repo.create(
            templateId: 't1',
            name: 'Soporte',
            channel: BotChannel.waUnofficial,
          ),
        ).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<Bot>.error(const BotsServerFailure());
          }
          return Future<Bot>.value(_bot);
        });
        return BotCreateBloc(repo: repo);
      },
      act: (bloc) async {
        bloc.add(
          const BotCreateSubmitted(
            templateId: 't1',
            name: 'Soporte',
            channel: BotChannel.waUnofficial,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const BotCreateSubmitted(
            templateId: 't1',
            name: 'Soporte',
            channel: BotChannel.waUnofficial,
          ),
        );
      },
      expect: () => const <BotCreateState>[
        BotCreateSubmitting(),
        BotCreateFailed(BotsServerFailure()),
        BotCreateSubmitting(),
        BotCreateSucceeded(_bot),
      ],
    );

    test('value-equality de los estados', () {
      expect(const BotCreateInitial(), equals(const BotCreateInitial()));
      expect(const BotCreateSubmitting(), equals(const BotCreateSubmitting()));
      expect(
        const BotCreateSucceeded(_bot),
        equals(const BotCreateSucceeded(_bot)),
      );
      expect(
        const BotCreateFailed(BotsNetworkFailure()),
        equals(const BotCreateFailed(BotsNetworkFailure())),
      );
    });

    test('value-equality de Submitted', () {
      expect(
        const BotCreateSubmitted(
          templateId: 't1',
          name: 'a',
          channel: BotChannel.waUnofficial,
        ),
        equals(
          const BotCreateSubmitted(
            templateId: 't1',
            name: 'a',
            channel: BotChannel.waUnofficial,
          ),
        ),
      );
      expect(
        const BotCreateSubmitted(
          templateId: 't1',
          name: 'a',
          channel: BotChannel.waUnofficial,
        ),
        isNot(
          equals(
            const BotCreateSubmitted(
              templateId: 't1',
              name: 'b',
              channel: BotChannel.waUnofficial,
            ),
          ),
        ),
      );
    });
  });
}
