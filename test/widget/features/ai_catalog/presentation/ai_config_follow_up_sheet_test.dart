import 'package:ataulfo/core/ai/ai_config.dart';
import 'package:ataulfo/core/design/app_bottom_sheet.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_select_field.dart';
import 'package:ataulfo/core/design/widgets/app_toggle_row.dart';
import 'package:ataulfo/features/ai_catalog/presentation/widgets/ai_config_follow_up_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AIConfig _ai({
  bool followUpEnabled = true,
  int followUpDelayMinutes = 1440,
  int followUpMaxAttempts = 2,
}) => AIConfig(
  enabled: true,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.medium,
  systemPrompt: '',
  contextMessages: 20,
  followUpEnabled: followUpEnabled,
  followUpDelayMinutes: followUpDelayMinutes,
  followUpMaxAttempts: followUpMaxAttempts,
);

void main() {
  // Abre la hoja como en producción (modal en otro subárbol del Navigator) y
  // captura el AIConfig del pop.
  Future<AIConfig?> Function() pumpHost(WidgetTester tester, AIConfig initial) {
    AIConfig? captured;
    var done = false;
    return () async {
      if (!done) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await showAppBottomSheet<AIConfig>(
                        ctx,
                        isScrollControlled: true,
                        builder: (_) => AiConfigFollowUpSheet(
                          keyPrefix: 'cfg',
                          initial: initial,
                        ),
                      );
                      done = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }
      return captured;
    };
  }

  testWidgets('toggle y selectores hablan el idioma del kit', (tester) async {
    final read = pumpHost(tester, _ai());
    await read();

    // AppToggleRow + dos AppSelectField (espera e intentos); nada de
    // SwitchListTile/DropdownButtonFormField crudos.
    expect(find.byType(AppToggleRow), findsOneWidget);
    expect(
      find.byKey(const Key('cfg.sheet.follow_up.enabled')),
      findsOneWidget,
    );
    expect(find.byType(AppSelectField<int>), findsNWidgets(2));
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
  });

  testWidgets('elegir espera y guardar devuelve el AIConfig actualizado', (
    tester,
  ) async {
    final read = pumpHost(tester, _ai());
    await read();

    await tester.tap(find.byKey(const Key('cfg.sheet.follow_up.delay')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hora').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cfg.sheet.follow_up.save')));
    await tester.pumpAndSettle();

    final result = await read();
    expect(result, isNotNull);
    expect(result!.followUpEnabled, isTrue);
    expect(result.followUpDelayMinutes, 60);
    expect(result.followUpMaxAttempts, 2);
  });

  testWidgets('una espera fuera del set se muestra como entrada propia', (
    tester,
  ) async {
    final read = pumpHost(tester, _ai(followUpDelayMinutes: 90));
    await read();

    // El sheet JAMÁS aparenta un valor distinto del que Guardar persiste.
    expect(find.text('90 min (personalizado)'), findsOneWidget);
  });

  testWidgets('apagado: los selectores se ocultan y el toggle los revive', (
    tester,
  ) async {
    final read = pumpHost(tester, _ai(followUpEnabled: false));
    await read();

    expect(find.byType(AppSelectField<int>), findsNothing);

    await tester.tap(find.byKey(const Key('cfg.sheet.follow_up.enabled')));
    await tester.pumpAndSettle();

    expect(find.byType(AppSelectField<int>), findsNWidgets(2));
  });
}
