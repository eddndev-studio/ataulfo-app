import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/flow_settings_tab.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

fdom.Flow _flow({
  String id = 'f1',
  String name = 'Bienvenida',
  bool isActive = true,
  int version = 3,
  int cooldownMs = 0,
  int usageLimit = 0,
  List<String> excludesFlows = const <String>[],
}) => fdom.Flow(
  id: id,
  templateId: 't1',
  name: name,
  isActive: isActive,
  version: version,
  cooldownMs: cooldownMs,
  usageLimit: usageLimit,
  excludesFlows: excludesFlows,
);

const _sib1 = fdom.Flow(
  id: 'f2',
  templateId: 't1',
  name: 'Despedida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _sib2 = fdom.Flow(
  id: 'f3',
  templateId: 't1',
  name: 'Recordatorio',
  isActive: false,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowDetailLoadRequested());
    registerFallbackValue(
      const FlowDetailUpdateSettingsRequested(
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      ),
    );
  });

  late _MockDetailBloc bloc;

  setUp(() {
    bloc = _MockDetailBloc();
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowDetailBloc>.value(
      value: bloc,
      child: const Scaffold(body: FlowSettingsTab()),
    ),
  );

  group('FlowSettingsTab — render inicial', () {
    testWidgets(
      'Loaded: muestra slider cooldown, number field usageLimit, multi-select de siblings',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowDetailLoaded(
            _flow(
              cooldownMs: 5000,
              usageLimit: 3,
              excludesFlows: <String>['f2'],
            ),
            const <fdom.Flow>[_sib1, _sib2],
            siblingsFailed: false,
          ),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('flow_settings.cooldown.slider')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_settings.usage_limit.field')),
          findsOneWidget,
        );
        // Chip por cada sibling.
        expect(
          find.byKey(const Key('flow_settings.excludes.chip.f2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_settings.excludes.chip.f3')),
          findsOneWidget,
        );
        // El nombre del sibling es visible.
        expect(find.text('Despedida'), findsOneWidget);
        expect(find.text('Recordatorio'), findsOneWidget);
      },
    );

    testWidgets('botón Guardar empieza disabled (no dirty)', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(cooldownMs: 5000, usageLimit: 3),
          const <fdom.Flow>[_sib1],
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      final btn = tester.widget<AppButton>(
        find.byKey(const Key('flow_settings.save_button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('usageLimit = 0 muestra label "Sin límite"', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(usageLimit: 0),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_settings.usage_limit.unlimited_label')),
        findsOneWidget,
      );
    });

    testWidgets(
      'siblings vacía (única flow de la template) muestra empty state inline',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowDetailLoaded(_flow(), const <fdom.Flow>[], siblingsFailed: false),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('flow_settings.excludes.empty')),
          findsOneWidget,
        );
      },
    );

    testWidgets('siblingsFailed=true muestra aviso de carga fallida', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(_flow(), const <fdom.Flow>[], siblingsFailed: true),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_settings.excludes.siblings_failed')),
        findsOneWidget,
      );
    });
  });

  group('FlowSettingsTab — dirty + save', () {
    testWidgets('cambiar usageLimit habilita el botón Guardar', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(usageLimit: 0),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('flow_settings.usage_limit.field')),
        '5',
      );
      await tester.pump();

      final btn = tester.widget<AppButton>(
        find.byKey(const Key('flow_settings.save_button')),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('tap en chip de sibling toggle de excludesFlows', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(excludesFlows: const <String>[]),
          const <fdom.Flow>[_sib1, _sib2],
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('flow_settings.excludes.chip.f2')));
      await tester.pump();

      final btn = tester.widget<AppButton>(
        find.byKey(const Key('flow_settings.save_button')),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets(
      'save dispatcha UpdateSettingsRequested con excludesFlows ordenado por id',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowDetailLoaded(_flow(), const <fdom.Flow>[
            _sib1,
            _sib2,
          ], siblingsFailed: false),
        );

        await tester.pumpWidget(host());

        // Selecciono primero f3 y luego f2: orden de selección distinto del id-sort.
        await tester.tap(
          find.byKey(const Key('flow_settings.excludes.chip.f3')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('flow_settings.excludes.chip.f2')),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('flow_settings.save_button')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowDetailUpdateSettingsRequested(
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>['f2', 'f3'],
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('Saving: botón Guardar disabled + indicador inline visible', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        FlowDetailSettingsSaving(
          _flow(),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      final btn = tester.widget<AppButton>(
        find.byKey(const Key('flow_settings.save_button')),
      );
      expect(btn.onPressed, isNull);
      expect(find.byKey(const Key('flow_settings.saving')), findsOneWidget);
    });
  });

  group('FlowSettingsTab — failure copy', () {
    testWidgets(
      'SaveFailed(Conflict): muestra copy de version stale + botón Recargar',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowDetailSettingsSaveFailed(
            _flow(),
            const <fdom.Flow>[],
            const FlowsConflictFailure(),
            siblingsFailed: false,
          ),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('flow_settings.error.conflict')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_settings.error.conflict.reload')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('flow_settings.error.conflict.reload')),
        );
        await tester.pump();

        verify(() => bloc.add(const FlowDetailLoadRequested())).called(1);
      },
    );

    testWidgets(
      'SaveFailed(InvalidSettings): muestra copy de invalid + sin botón recargar',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowDetailSettingsSaveFailed(
            _flow(),
            const <fdom.Flow>[],
            const FlowsInvalidSettingsFailure(),
            siblingsFailed: false,
          ),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('flow_settings.error.invalid_settings')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_settings.error.conflict.reload')),
          findsNothing,
        );
      },
    );

    testWidgets('SaveFailed(NotFound): copy de flow no existe', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailSettingsSaveFailed(
          _flow(),
          const <fdom.Flow>[],
          const FlowsNotFoundFailure(),
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_settings.error.not_found')),
        findsOneWidget,
      );
    });

    testWidgets('SaveFailed(Forbidden): copy de rol insuficiente', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        FlowDetailSettingsSaveFailed(
          _flow(),
          const <fdom.Flow>[],
          const FlowsForbiddenFailure(),
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_settings.error.forbidden')),
        findsOneWidget,
      );
    });

    testWidgets('SaveFailed(Network): copy genérico de red', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailSettingsSaveFailed(
          _flow(),
          const <fdom.Flow>[],
          const FlowsNetworkFailure(),
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_settings.error.network')),
        findsOneWidget,
      );
    });

    testWidgets('SaveFailed(Server): copy genérico server', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailSettingsSaveFailed(
          _flow(),
          const <fdom.Flow>[],
          const FlowsServerFailure(),
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_settings.error.server')),
        findsOneWidget,
      );
    });
  });

  group('FlowSettingsTab — re-hidratación', () {
    testWidgets('cambio de version del flow re-hidrata el form (ValueKey)', (
      tester,
    ) async {
      // Empieza con cooldown=0, version=1.
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(version: 1, cooldownMs: 0),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );
      await tester.pumpWidget(host());

      // El form refleja cooldown=0 (no dirty).
      final btnInicial = tester.widget<AppButton>(
        find.byKey(const Key('flow_settings.save_button')),
      );
      expect(btnInicial.onPressed, isNull);

      // El bloc emite Loaded con version=2 + cooldown=5000 (post-save).
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(version: 2, cooldownMs: 5000),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );
      await tester.pumpWidget(host());

      // El form re-hidrata desde el nuevo snapshot ⇒ no dirty.
      final btnPostSave = tester.widget<AppButton>(
        find.byKey(const Key('flow_settings.save_button')),
      );
      expect(btnPostSave.onPressed, isNull);
    });
  });

  group('FlowSettingsTab — cooldown en horas (hasta 5 días)', () {
    testWidgets('cooldown de 5 días muestra label "5d"', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(cooldownMs: 5 * 24 * 60 * 60 * 1000),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );
      await tester.pumpWidget(host());
      expect(find.textContaining('5d'), findsOneWidget);
    });

    testWidgets('cooldown de 2h muestra label "2h"', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(cooldownMs: 2 * 60 * 60 * 1000),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );
      await tester.pumpWidget(host());
      expect(find.textContaining('2h'), findsOneWidget);
    });

    testWidgets('cooldown de 25h muestra label "1d 1h"', (tester) async {
      when(() => bloc.state).thenReturn(
        FlowDetailLoaded(
          _flow(cooldownMs: 25 * 60 * 60 * 1000),
          const <fdom.Flow>[],
          siblingsFailed: false,
        ),
      );
      await tester.pumpWidget(host());
      expect(find.textContaining('1d 1h'), findsOneWidget);
    });

    testWidgets(
      'arrastrar el slider al máximo y guardar manda cooldownMs de 5 días',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowDetailLoaded(
            _flow(cooldownMs: 0),
            const <fdom.Flow>[],
            siblingsFailed: false,
          ),
        );
        await tester.pumpWidget(host());

        // Arrastra a la derecha más allá del ancho del slider → tope (120h).
        await tester.drag(
          find.byKey(const Key('flow_settings.cooldown.slider')),
          const Offset(2000, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('flow_settings.save_button')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowDetailUpdateSettingsRequested(
              cooldownMs: 5 * 24 * 60 * 60 * 1000,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'cooldown sub-hora intacto se PRESERVA al guardar otro campo (no se pone en 0)',
      (tester) async {
        // Un cooldown legacy de 5s redondea a 0h en la escala de horas, pero si
        // el operador NO toca el slider, guardar otro campo debe preservar el
        // valor original exacto en vez de zerarlo.
        when(() => bloc.state).thenReturn(
          FlowDetailLoaded(
            _flow(cooldownMs: 5000, usageLimit: 0),
            const <fdom.Flow>[],
            siblingsFailed: false,
          ),
        );
        await tester.pumpWidget(host());

        await tester.enterText(
          find.byKey(const Key('flow_settings.usage_limit.field')),
          '5',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('flow_settings.save_button')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowDetailUpdateSettingsRequested(
              cooldownMs: 5000,
              usageLimit: 5,
              excludesFlows: <String>[],
            ),
          ),
        ).called(1);
      },
    );
  });
}
