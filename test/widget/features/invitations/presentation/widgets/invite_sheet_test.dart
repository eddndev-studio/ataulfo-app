import 'dart:async';

import 'package:ataulfo/core/design/app_bottom_sheet.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_radio_row.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/core/platform/share_service.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/invitations/domain/entities/created_invitation.dart';
import 'package:ataulfo/features/invitations/domain/failures/invitations_failure.dart';
import 'package:ataulfo/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:ataulfo/features/invitations/presentation/widgets/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements InvitationsRepository {}

class _FakeShareService implements ShareService {
  String? lastText;

  @override
  Future<void> shareText(String text, {String? subject}) async {
    lastText = text;
  }
}

class _OpenSession {
  Future<bool>? result;
  bool? outcome;
}

Bot _bot(int index) => Bot(
  id: 'b$index',
  orgId: 'o1',
  templateId: 't1',
  name: switch (index) {
    1 => 'Ventas',
    2 => 'Soporte',
    3 => 'Agenda',
    _ => 'Canal $index',
  },
  channel: index.isEven ? BotChannel.waba : BotChannel.waUnofficial,
  identifier: null,
  version: 1,
  paused: false,
  aiDisabled: false,
);

void main() {
  late _MockRepo repo;
  late _FakeShareService share;

  setUp(() {
    repo = _MockRepo();
    share = _FakeShareService();
    when(() => repo.create(any(), any(), any())).thenAnswer(
      (_) async => const CreatedInvitation(
        email: 'persona@empresa.com',
        token: 'RAW-TOKEN',
        emailSent: true,
      ),
    );
  });

  Future<_OpenSession> pumpHost(WidgetTester tester, {List<Bot>? bots}) async {
    final session = _OpenSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: RepositoryProvider<InvitationsRepository>.value(
          value: repo,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    final result = InviteSheet.open(
                      context,
                      bots: bots ?? <Bot>[_bot(1), _bot(2)],
                      shareService: share,
                    );
                    session.result = result;
                    unawaited(
                      result.then((value) {
                        session.outcome = value;
                      }),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> goToAccess(
    WidgetTester tester, {
    String email = 'persona@empresa.com',
  }) async {
    await tester.enterText(find.byKey(const Key('invite.email')), email);
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite.continue')));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('abre en 1 de 2 · Persona con explicación y pie canónico', (
    tester,
  ) async {
    await pumpHost(tester);

    expect(find.byKey(const Key('invite.step.person')), findsOneWidget);
    expect(find.text('1 de 2 · Persona'), findsOneWidget);
    expect(find.textContaining('correo que usará para entrar'), findsOneWidget);
    expect(find.byKey(const Key('invite.email')), findsOneWidget);
    expect(
      tester
          .widget<AppTextField>(find.byKey(const Key('invite.email')))
          .autofocus,
      isFalse,
    );
    expect(find.byKey(const Key('invite.cancel')), findsOneWidget);
    expect(find.byKey(const Key('invite.continue')), findsOneWidget);
    expect(find.byKey(const Key('invite.role.WORKER')), findsNothing);
  });

  testWidgets('Continuar exige email válido y Enter avanza al acceso', (
    tester,
  ) async {
    await pumpHost(tester);

    AppButton button() =>
        tester.widget<AppButton>(find.byKey(const Key('invite.continue')));

    expect(button().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('invite.email')), 'invalido');
    await tester.pump();
    expect(button().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('invite.email')),
      'persona@empresa.com',
    );
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite.step.access')), findsOneWidget);
  });

  testWidgets(
    'Persona y Acceso se deslizan de lado sin fundirse ni superponerse',
    (tester) async {
      await pumpHost(tester);
      await tester.enterText(
        find.byKey(const Key('invite.email')),
        'persona@empresa.com',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('invite.continue')));
      await tester.pump();
      await tester.pump(AppTokens.durationBase ~/ 2);

      final viewport = find.byKey(const Key('invite.step_transition'));
      expect(viewport, findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('invite.step.person')),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('invite.step.access')),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: viewport, matching: find.byType(SlideTransition)),
        findsAtLeastNWidgets(2),
      );

      final personX = tester
          .getCenter(find.byKey(const Key('invite.step.person')))
          .dx;
      final accessX = tester
          .getCenter(find.byKey(const Key('invite.step.access')))
          .dx;
      expect(personX, lessThan(accessX));
      expect(
        accessX - personX,
        greaterThan(AppTokens.sp9),
        reason: 'las vistas deben viajar lado a lado, no ocupar el mismo plano',
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite.step.person')), findsNothing);
      expect(find.byKey(const Key('invite.step.access')), findsOneWidget);
    },
  );

  testWidgets('2 de 2 · Acceso resume el correo y explica los tres roles', (
    tester,
  ) async {
    await pumpHost(tester);
    await goToAccess(tester);

    expect(find.text('2 de 2 · Acceso'), findsOneWidget);
    expect(find.byKey(const Key('invite.email_summary')), findsOneWidget);
    expect(find.text('persona@empresa.com'), findsOneWidget);
    expect(find.byType(AppRadioRow<String>), findsNWidgets(3));
    expect(find.text('Agente'), findsOneWidget);
    expect(find.textContaining('Canales que selecciones'), findsOneWidget);
    expect(find.text('Supervisor'), findsOneWidget);
    expect(find.textContaining('todos los Canales operativos'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.textContaining('equipo y configuración'), findsOneWidget);
  });

  testWidgets('Atrás conserva el correo y permite volver a Acceso', (
    tester,
  ) async {
    await pumpHost(tester);
    await goToAccess(tester);

    await tester.tap(find.byKey(const Key('invite.back')));
    await tester.pumpAndSettle();

    expect(find.text('1 de 2 · Persona'), findsOneWidget);
    final field = tester.widget<AppTextField>(
      find.byKey(const Key('invite.email')),
    );
    expect(field.controller.text, 'persona@empresa.com');

    await tester.tap(find.byKey(const Key('invite.continue')));
    await tester.pumpAndSettle();
    expect(find.text('2 de 2 · Acceso'), findsOneWidget);
  });

  testWidgets('Agente muestra multiselección, contador y acceso cero neutral', (
    tester,
  ) async {
    await pumpHost(tester);
    await goToAccess(tester);

    expect(find.byKey(const Key('invite.channels')), findsOneWidget);
    expect(find.text('0 de 2 seleccionados'), findsOneWidget);
    expect(
      find.byKey(const Key('invite.channels.assign_later')),
      findsOneWidget,
    );
    expect(find.textContaining('asignarlos después'), findsOneWidget);
    expect(find.byKey(const Key('invite.channels.warning')), findsNothing);

    await tapVisible(tester, find.byKey(const Key('invite.channel.b2')));
    expect(find.text('1 de 2 seleccionados'), findsOneWidget);
  });

  testWidgets('la búsqueda aparece con seis Canales y conserva el contador', (
    tester,
  ) async {
    await pumpHost(
      tester,
      bots: List<Bot>.generate(6, (index) => _bot(index + 1)),
    );
    await goToAccess(tester);

    expect(find.byKey(const Key('invite.channels.search')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('invite.channel.b2')));
    expect(find.text('1 de 6 seleccionados'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('invite.channels.search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('invite.channels.search')),
      'Ventas',
    );
    await tester.pump();

    expect(find.byKey(const Key('invite.channel.b1')), findsOneWidget);
    expect(find.byKey(const Key('invite.channel.b2')), findsNothing);
    expect(find.text('1 de 6 seleccionados'), findsOneWidget);
  });

  testWidgets('rol elevado oculta Canales y envía la selección vacía', (
    tester,
  ) async {
    await pumpHost(tester);
    await goToAccess(tester);

    await tapVisible(tester, find.byKey(const Key('invite.channel.b1')));
    await tapVisible(tester, find.byKey(const Key('invite.role.SUPERVISOR')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite.channels')), findsNothing);
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pump();

    verify(
      () => repo.create('persona@empresa.com', 'SUPERVISOR', const <String>[]),
    ).called(1);
  });

  testWidgets('Enviar conserva la hoja, bloquea controles y muestra progreso', (
    tester,
  ) async {
    final completer = Completer<CreatedInvitation>();
    when(
      () => repo.create(any(), any(), any()),
    ).thenAnswer((_) => completer.future);

    await pumpHost(tester);
    await goToAccess(tester);
    await tapVisible(tester, find.byKey(const Key('invite.channel.b2')));
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pump();

    expect(find.byKey(const Key('invite.step.access')), findsOneWidget);
    final submit = tester.widget<AppButton>(
      find.byKey(const Key('invite.submit')),
    );
    expect(submit.loading, isTrue);
    expect(submit.label, 'Creando invitación…');
    expect(
      tester
          .widget<AppRadioRow<String>>(
            find.byKey(const Key('invite.role.WORKER')),
          )
          .onChanged,
      isNull,
    );

    // La barrera no descarta una operación en vuelo.
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.byKey(const Key('invite.step.access')), findsOneWidget);
    expect(find.text('¿Descartar los cambios?'), findsNothing);

    completer.complete(
      const CreatedInvitation(
        email: 'persona@empresa.com',
        token: 'RAW-TOKEN',
        emailSent: true,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'éxito transforma la misma hoja y Listo cierra con refresh=true',
    (tester) async {
      final session = await pumpHost(tester);
      await goToAccess(tester);

      await tester.tap(find.byKey(const Key('invite.submit')));
      await tester.pumpAndSettle();

      expect(find.text('Invitación creada'), findsOneWidget);
      expect(find.byKey(const Key('invite.step.access')), findsNothing);
      expect(find.text('RAW-TOKEN'), findsOneWidget);
      expect(
        find.byKey(const Key('invitation_share.copy_code')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invitation_share.share_message')),
        findsOneWidget,
      );
      expect(session.outcome, isNull);

      await tapVisible(tester, find.byKey(const Key('invitation_share.done')));
      await tester.pumpAndSettle();
      expect(find.text('Invitación creada'), findsNothing);
      expect(session.outcome, isTrue);
      expect(await session.result, isTrue);
    },
  );

  testWidgets('fallo queda inline, conserva el borrador y permite reintentar', (
    tester,
  ) async {
    var attempts = 0;
    when(() => repo.create(any(), any(), any())).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw const InvitationsDuplicateFailure();
      return const CreatedInvitation(
        email: 'persona@empresa.com',
        token: 'RAW-TOKEN',
        emailSent: false,
      );
    });

    await pumpHost(tester);
    await goToAccess(tester);
    await tapVisible(tester, find.byKey(const Key('invite.channel.b1')));
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite.failure')), findsOneWidget);
    expect(
      find.textContaining('invitación pendiente para ese correo'),
      findsOneWidget,
    );
    expect(find.text('persona@empresa.com'), findsOneWidget);
    expect(find.text('1 de 2 seleccionados'), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invitación creada'), findsOneWidget);
    verify(
      () => repo.create('persona@empresa.com', 'WORKER', const <String>['b1']),
    ).called(2);
  });

  testWidgets('un 5xx conserva refresh aunque se corrija antes de descartar', (
    tester,
  ) async {
    when(
      () => repo.create(any(), any(), any()),
    ).thenThrow(const InvitationsServerFailure());

    final session = await pumpHost(tester);
    await goToAccess(tester);
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite.failure')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite.step.person')), findsOneWidget);

    // Volver limpió el estado visual del cubit, pero no la incertidumbre de
    // que el servidor haya persistido la invitación antes del 5xx.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(appSheetDiscardConfirmKey));
    await tester.pumpAndSettle();

    expect(await session.result, isTrue);
  });

  testWidgets('Compartir desde el éxito usa correo y código del resultado', (
    tester,
  ) async {
    await pumpHost(tester);
    await goToAccess(tester);
    await tester.tap(find.byKey(const Key('invite.submit')));
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const Key('invitation_share.share_message')),
    );
    await tester.pumpAndSettle();

    expect(share.lastText, contains('persona@empresa.com'));
    expect(share.lastText, contains('RAW-TOKEN'));
  });

  testWidgets('descartar un correo escrito pasa por el guard de cambios', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.enterText(
      find.byKey(const Key('invite.email')),
      'persona@empresa.com',
    );
    await tester.pump();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.byKey(appSheetDiscardCancelKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite.step.person')), findsOneWidget);
  });
}
