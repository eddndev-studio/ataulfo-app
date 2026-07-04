import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/messages/data/media/noop_audio_recorder.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/core/audio/audio_recorder.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:ataulfo/features/messages/presentation/widgets/message_composer.dart';
import 'package:ataulfo/features/quick_replies/domain/entities/quick_reply.dart';
import 'package:ataulfo/features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagesBloc extends MockBloc<MessagesEvent, MessagesState>
    implements MessagesBloc {}

class _MockQuickRepliesBloc
    extends MockBloc<QuickRepliesEvent, QuickRepliesState>
    implements QuickRepliesBloc {}

QuickReply _qr({
  String id = '61',
  String shortcut = 'saludo',
  String message = 'Hola, ¿en qué te ayudo?',
  bool deleted = false,
}) => QuickReply(
  waQuickReplyId: id,
  shortcut: shortcut,
  message: message,
  deleted: deleted,
);

void main() {
  late _MockMessagesBloc msgBloc;
  late _MockQuickRepliesBloc qrBloc;

  setUp(() {
    msgBloc = _MockMessagesBloc();
    qrBloc = _MockQuickRepliesBloc();
    when(() => msgBloc.state).thenReturn(
      const MessagesLoaded(
        items: <Message>[],
        prevCursor: null,
        isLoadingOlder: false,
      ),
    );
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: RepositoryProvider<AudioRecorder>.value(
      value: const NoopAudioRecorder(),
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<MessagesBloc>.value(value: msgBloc),
          BlocProvider<QuickRepliesBloc>.value(value: qrBloc),
          BlocProvider<ReplyDraftCubit>(create: (_) => ReplyDraftCubit()),
        ],
        child: const Scaffold(body: MessageComposer()),
      ),
    ),
  );

  String inputText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('composer.input')))
      .controller!
      .text;

  testWidgets('el botón ⚡ está visible', (tester) async {
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('composer.quickreply')), findsOneWidget);
  });

  testWidgets(
    'tap ⚡ en campo NUNCA enfocado inserta el message (sin RangeError)',
    (tester) async {
      when(() => qrBloc.state).thenReturn(
        QuickRepliesLoaded(<QuickReply>[_qr(message: 'Hola mundo')]),
      );
      await tester.pumpWidget(host());

      // Sin tocar el input: selection.offset == -1 (inválida).
      await tester.tap(find.byKey(const Key('composer.quickreply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('saludo'));
      await tester.pumpAndSettle();

      expect(inputText(tester), 'Hola mundo');
    },
  );

  testWidgets('tap ⚡ con texto existente inserta en el cursor', (tester) async {
    when(
      () => qrBloc.state,
    ).thenReturn(QuickRepliesLoaded(<QuickReply>[_qr(message: 'gracias')]));
    await tester.pumpWidget(host());

    await tester.enterText(find.byKey(const Key('composer.input')), 'Hola ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer.quickreply')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('saludo'));
    await tester.pumpAndSettle();

    expect(inputText(tester), 'Hola gracias');
  });

  testWidgets('tap ⚡ con catálogo sin activos → SnackBar, sin sheet', (
    tester,
  ) async {
    when(
      () => qrBloc.state,
    ).thenReturn(QuickRepliesLoaded(<QuickReply>[_qr(deleted: true)]));
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('composer.quickreply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_replies_sheet')), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tap ⚡ mientras carga → SnackBar, sin sheet', (tester) async {
    when(() => qrBloc.state).thenReturn(const QuickRepliesLoading());
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('composer.quickreply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick_replies_sheet')), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
