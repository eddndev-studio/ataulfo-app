import 'package:ataulfo/features/quick_replies/domain/entities/quick_reply.dart';
import 'package:ataulfo/features/quick_replies/domain/failures/quick_replies_failure.dart';
import 'package:ataulfo/features/quick_replies/domain/repositories/quick_replies_repository.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements QuickRepliesRepository {}

QuickReply _qr({
  String id = '61',
  String shortcut = 'saludo',
  String message = 'Hola',
  bool deleted = false,
}) => QuickReply(
  waQuickReplyId: id,
  shortcut: shortcut,
  message: message,
  deleted: deleted,
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  QuickRepliesBloc build() => QuickRepliesBloc(repo: repo, botId: 'b1');

  test('estado inicial es Loading', () {
    expect(build().state, const QuickRepliesLoading());
  });

  test('expone el botId con que se construyó', () {
    expect(build().botId, 'b1');
  });

  blocTest<QuickRepliesBloc, QuickRepliesState>(
    'load → Loaded con el catálogo completo (incluye tombstones)',
    build: () {
      when(() => repo.listCatalog('b1')).thenAnswer(
        (_) async => <QuickReply>[_qr(), _qr(id: '62', deleted: true)],
      );
      return build();
    },
    act: (b) => b.add(const QuickRepliesLoadRequested()),
    expect: () => <QuickRepliesState>[
      QuickRepliesLoaded(<QuickReply>[_qr(), _qr(id: '62', deleted: true)]),
    ],
    verify: (_) => verify(() => repo.listCatalog('b1')).called(1),
  );

  blocTest<QuickRepliesBloc, QuickRepliesState>(
    'load con catálogo vacío → Loaded vacío',
    build: () {
      when(
        () => repo.listCatalog('b1'),
      ).thenAnswer((_) async => <QuickReply>[]);
      return build();
    },
    act: (b) => b.add(const QuickRepliesLoadRequested()),
    expect: () => <QuickRepliesState>[const QuickRepliesLoaded(<QuickReply>[])],
  );

  blocTest<QuickRepliesBloc, QuickRepliesState>(
    'load que falla → Failed con la failure tipada',
    build: () {
      when(
        () => repo.listCatalog('b1'),
      ).thenThrow(const QuickRepliesForbiddenFailure());
      return build();
    },
    act: (b) => b.add(const QuickRepliesLoadRequested()),
    expect: () => <QuickRepliesState>[
      const QuickRepliesFailed(QuickRepliesForbiddenFailure()),
    ],
  );

  blocTest<QuickRepliesBloc, QuickRepliesState>(
    'reintento tras Failed: re-emite Loading antes de Loaded',
    build: () {
      var calls = 0;
      when(() => repo.listCatalog('b1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const QuickRepliesServerFailure();
        return <QuickReply>[_qr()];
      });
      return build();
    },
    act: (b) async {
      b.add(const QuickRepliesLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const QuickRepliesLoadRequested());
    },
    expect: () => <QuickRepliesState>[
      const QuickRepliesFailed(QuickRepliesServerFailure()),
      const QuickRepliesLoading(),
      QuickRepliesLoaded(<QuickReply>[_qr()]),
    ],
  );
}
