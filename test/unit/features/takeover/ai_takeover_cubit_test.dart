import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/takeover/domain/silence_labels_resolver.dart';
import 'package:ataulfo/features/takeover/presentation/cubit/ai_takeover_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockResolver extends Mock implements SilenceLabelsResolver {}

class _MockChatLabels extends Mock implements ChatLabelsRepository {}

Label _lab(String id) =>
    Label(id: id, name: id, color: '#000000', description: '');

void main() {
  late _MockResolver resolver;
  late _MockChatLabels chatLabels;

  setUp(() {
    resolver = _MockResolver();
    chatLabels = _MockChatLabels();
  });

  AiTakeoverCubit build() => AiTakeoverCubit(
    resolver: resolver,
    chatLabels: chatLabels,
    botId: 'b1',
    chatLid: 'c1',
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'load: etiqueta de silencio configurada y presente en el chat → pausado',
    build: () {
      when(() => resolver.forBot('b1')).thenAnswer((_) async => <String>['s1']);
      when(
        () => chatLabels.listForChat('b1', 'c1'),
      ).thenAnswer((_) async => <Label>[_lab('s1'), _lab('otra')]);
      return build();
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<AiTakeoverReady>()
          .having((s) => s.configured, 'configured', true)
          .having((s) => s.paused, 'paused', true),
    ],
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'load: configurada pero NO presente → no pausado',
    build: () {
      when(() => resolver.forBot('b1')).thenAnswer((_) async => <String>['s1']);
      when(
        () => chatLabels.listForChat('b1', 'c1'),
      ).thenAnswer((_) async => <Label>[_lab('otra')]);
      return build();
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<AiTakeoverReady>()
          .having((s) => s.configured, 'configured', true)
          .having((s) => s.paused, 'paused', false),
    ],
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'load: sin etiquetas de silencio configuradas → no configurado',
    build: () {
      when(() => resolver.forBot('b1')).thenAnswer((_) async => <String>[]);
      when(
        () => chatLabels.listForChat('b1', 'c1'),
      ).thenAnswer((_) async => <Label>[]);
      return build();
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<AiTakeoverReady>().having((s) => s.configured, 'configured', false),
    ],
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'load: error de I/O → AiTakeoverError',
    build: () {
      when(() => resolver.forBot('b1')).thenThrow(const LabelsNetworkFailure());
      return build();
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[isA<AiTakeoverError>()],
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'toggle desde no-pausado: aplica la primera etiqueta de silencio',
    build: () {
      when(
        () => chatLabels.addToChat('b1', 'c1', 's1'),
      ).thenAnswer((_) async {});
      return build();
    },
    seed: () => const AiTakeoverReady(
      silenceIds: <String>['s1'],
      presentIds: <String>[],
    ),
    act: (c) => c.toggle(),
    expect: () => <Matcher>[
      isA<AiTakeoverReady>().having((s) => s.busy, 'busy', true),
      isA<AiTakeoverReady>()
          .having((s) => s.busy, 'busy', false)
          .having((s) => s.paused, 'paused', true),
    ],
    verify: (_) => verify(() => chatLabels.addToChat('b1', 'c1', 's1')).called(1),
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'toggle desde pausado: quita las etiquetas de silencio presentes',
    build: () {
      when(
        () => chatLabels.removeFromChat('b1', 'c1', 's1'),
      ).thenAnswer((_) async {});
      return build();
    },
    seed: () => const AiTakeoverReady(
      silenceIds: <String>['s1'],
      presentIds: <String>['s1'],
    ),
    act: (c) => c.toggle(),
    expect: () => <Matcher>[
      isA<AiTakeoverReady>().having((s) => s.busy, 'busy', true),
      isA<AiTakeoverReady>()
          .having((s) => s.busy, 'busy', false)
          .having((s) => s.paused, 'paused', false),
    ],
    verify: (_) =>
        verify(() => chatLabels.removeFromChat('b1', 'c1', 's1')).called(1),
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'toggle sin configurar → no-op (no toca el repo)',
    build: build,
    seed: () => const AiTakeoverReady(
      silenceIds: <String>[],
      presentIds: <String>[],
    ),
    act: (c) => c.toggle(),
    expect: () => <Matcher>[],
    verify: (_) {
      verifyNever(
        () => chatLabels.addToChat(any(), any(), any()),
      );
    },
  );

  blocTest<AiTakeoverCubit, AiTakeoverState>(
    'toggle con fallo → conserva estado y marca actionFailed',
    build: () {
      when(
        () => chatLabels.addToChat('b1', 'c1', 's1'),
      ).thenThrow(const LabelsNetworkFailure());
      return build();
    },
    seed: () => const AiTakeoverReady(
      silenceIds: <String>['s1'],
      presentIds: <String>[],
    ),
    act: (c) => c.toggle(),
    expect: () => <Matcher>[
      isA<AiTakeoverReady>().having((s) => s.busy, 'busy', true),
      isA<AiTakeoverReady>()
          .having((s) => s.busy, 'busy', false)
          .having((s) => s.paused, 'paused', false)
          .having((s) => s.actionFailed, 'actionFailed', true),
    ],
  );
}
