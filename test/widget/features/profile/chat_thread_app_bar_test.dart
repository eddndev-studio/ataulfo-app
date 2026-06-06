import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:ataulfo/features/flow_run/domain/entities/runnable_flow.dart';
import 'package:ataulfo/features/flow_run/domain/repositories/flow_run_repository.dart';
import 'package:ataulfo/features/flow_run/presentation/widgets/flow_run_sheet.dart';
import 'package:ataulfo/features/profile/presentation/widgets/chat_thread_app_bar.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:ataulfo/features/wa_labels/presentation/widgets/wa_chat_labels_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

class _MockFlowRunRepo extends Mock implements FlowRunRepository {}

void main() {
  late _MockProfileBloc bloc;
  setUp(() {
    bloc = _MockProfileBloc();
    when(() => bloc.state).thenReturn(const ProfileInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: const Scaffold(
        appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
        body: SizedBox.shrink(),
      ),
    ),
  );

  testWidgets('cargado muestra el nombre real + avatar', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(AppAvatar), findsOneWidget);
  });

  testWidgets('mientras carga cae al chatLid (no bloquea el header)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    expect(find.text('lid-dm'), findsOneWidget);
  });

  testWidgets('el header es tappable (InkWell para abrir el perfil)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    // El header (bajo el Semantics "Ver perfil") es tappable; el botón de
    // etiquetas del app bar aporta su propio ink, así que se acota al header.
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.hint == 'Ver perfil',
        ),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
  });

  testWidgets('GROUP sin displayName cae a "Grupo"', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'g@g.us',
          isGroup: true,
          phone: null,
          displayName: null,
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Grupo'), findsOneWidget);
  });

  testWidgets('DM sin displayName cae al phone', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: null,
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('521555'), findsOneWidget);
  });

  testWidgets('el header se anuncia como botón con hint "Ver perfil"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    final sem = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.hint == 'Ver perfil',
      ),
    );
    expect(sem.properties.button, isTrue);
    expect(sem.properties.label, 'Alice');
  });

  group('etiquetas de WhatsApp', () {
    testWidgets('muestra el botón de etiquetas', (tester) async {
      when(() => bloc.state).thenReturn(const ProfileLoading());
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('thread.labels')), findsOneWidget);
    });

    testWidgets('tocar abre el sheet de etiquetas del chat', (tester) async {
      final waRepo = _MockWaLabelsRepo();
      when(
        () => waRepo.listCatalog(any()),
      ).thenAnswer((_) async => <WaLabel>[]);
      when(
        () => waRepo.listChatAssocs(any()),
      ).thenAnswer((_) async => <WaChatAssoc>[]);
      when(
        () => waRepo.liveEvents(any()),
      ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
      when(() => bloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: RepositoryProvider<WaLabelsRepository>.value(
            value: waRepo,
            child: BlocProvider<ProfileBloc>.value(
              value: bloc,
              child: const Scaffold(
                appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('thread.labels')));
      await tester.pumpAndSettle();
      expect(find.byType(WaChatLabelsSheet), findsOneWidget);
    });
  });

  group('correr flujo', () {
    testWidgets('muestra el botón de correr flujo', (tester) async {
      when(() => bloc.state).thenReturn(const ProfileLoading());
      await tester.pumpWidget(host());
      expect(find.byKey(const Key('thread.run_flow')), findsOneWidget);
    });

    testWidgets('tocar abre el sheet de correr flujo', (tester) async {
      final runRepo = _MockFlowRunRepo();
      when(
        () => runRepo.listRunnable(any()),
      ).thenAnswer((_) async => <RunnableFlow>[]);
      when(() => bloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: RepositoryProvider<FlowRunRepository>.value(
            value: runRepo,
            child: BlocProvider<ProfileBloc>.value(
              value: bloc,
              child: const Scaffold(
                appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
                body: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('thread.run_flow')));
      await tester.pumpAndSettle();
      expect(find.byType(FlowRunSheet), findsOneWidget);
    });
  });
}
