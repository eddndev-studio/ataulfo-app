import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_entity_icon.dart';
import 'package:ataulfo/core/design/widgets/app_section_link.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:ataulfo/features/bots/presentation/widgets/bot_tool_permissions.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<BotDetailEvent, BotDetailState>
    implements BotDetailBloc {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

Template _tmpl({List<String> disabled = const <String>[]}) => Template(
  id: 't1',
  orgId: 'o1',
  name: 'Plantilla',
  version: 1,
  ai: AIConfig(
    enabled: true,
    provider: AIProvider.openai,
    model: 'gpt',
    temperature: 0.7,
    thinkingLevel: ThinkingLevel.low,
    systemPrompt: '',
    contextMessages: 10,
    disabledToolGroups: disabled,
  ),
);

// El bot restringe 'notas' por su cuenta.
const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
  disabledToolGroups: <String>['notas'],
);

void main() {
  late _MockBloc bloc;
  late _MockTemplatesRepo repo;

  setUp(() {
    bloc = _MockBloc();
    repo = _MockTemplatesRepo();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: RepositoryProvider<TemplatesRepository>.value(
        value: repo,
        child: BlocProvider<BotDetailBloc>.value(
          value: bloc,
          child: const BotToolPermissions(bot: _bot, isMutating: false),
        ),
      ),
    ),
  );

  testWidgets('resume el override del bot y la restricción de la plantilla', (
    tester,
  ) async {
    when(
      () => repo.byId('t1'),
    ).thenAnswer((_) async => _tmpl(disabled: const <String>['flujos']));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 grupo restringido por este bot'),
      findsOneWidget,
    );
    expect(find.textContaining('la plantilla ya restringe 1'), findsOneWidget);
  });

  testWidgets('la fila es un AppSectionLink del kit con glifo de entidad', (
    tester,
  ) async {
    when(
      () => repo.byId('t1'),
    ).thenAnswer((_) async => _tmpl(disabled: const <String>['flujos']));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // La fila no reinventa el launcher: usa AppSectionLink (glifo 44 +
    // titleMedium + chevron), consistente con el resto del detalle.
    final link = tester.widget<AppSectionLink>(find.byType(AppSectionLink));
    expect(link.onTap, isNotNull);
    expect(find.byType(AppEntityIcon), findsOneWidget);
    expect(find.text('Permisos de herramientas'), findsOneWidget);
  });

  testWidgets('mientras la plantilla carga, la fila queda inerte', (
    tester,
  ) async {
    // Future que nunca completa: el estado "comprobando…" queda estable.
    when(() => repo.byId('t1')).thenAnswer((_) => Completer<Template>().future);

    await tester.pumpWidget(host());
    await tester.pump();

    final link = tester.widget<AppSectionLink>(find.byType(AppSectionLink));
    expect(link.onTap, isNull);
    expect(
      find.textContaining('Comprobando los permisos de la plantilla'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tap abre el sheet (plantilla bloqueada) y Guardar despacha la deny-list del bot',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(
        () => repo.byId('t1'),
      ).thenAnswer((_) async => _tmpl(disabled: const <String>['flujos']));

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bot_detail.tool_permissions')));
      await tester.pumpAndSettle();
      // Título del sheet + label de la fila ⇒ al menos uno.
      expect(find.text('Permisos de herramientas'), findsWidgets);

      // Guardar SIN cambios: el grupo bloqueado por la plantilla (flujos) NO
      // entra en la deny-list del bot; sólo se preserva la propia ('notas').
      await tester.tap(find.byKey(const Key('tool_groups.sheet.save')));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const BotDetailUpdateRequested(disabledToolGroups: <String>['notas']),
        ),
      ).called(1);
    },
  );
}
