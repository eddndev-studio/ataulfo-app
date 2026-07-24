import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_wizard_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required Widget body,
    required Widget footer,
    double bottomInset = 0,
    double? bodyViewportFraction,
  }) {
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: bottomInset)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppWizardSheet(
              key: const Key('wizard.sheet'),
              bodyViewportFraction: bodyViewportFraction,
              body: body,
              footer: footer,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('header expresa paso, título, apoyo y progreso segmentado', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        body: const AppWizardStepHeader(
          step: 1,
          totalSteps: 2,
          title: 'Persona',
          description: 'El correo que usará para entrar.',
        ),
        footer: const SizedBox.shrink(),
      ),
    );

    expect(find.text('1 de 2 · Persona'), findsOneWidget);
    expect(find.text('El correo que usará para entrar.'), findsOneWidget);
    expect(find.byKey(const Key('app_wizard.progress.1')), findsOneWidget);
    expect(find.byKey(const Key('app_wizard.progress.2')), findsOneWidget);
  });

  testWidgets('footer mantiene acciones visibles fuera del scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        body: Column(
          children: List<Widget>.generate(
            20,
            (index) => SizedBox(height: 48, child: Text('Fila $index')),
          ),
        ),
        footer: Row(
          children: <Widget>[
            Expanded(
              child: AppButton.tonal(
                key: const Key('secondary'),
                label: 'Atrás',
                fullWidth: true,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton.filled(
                key: const Key('primary'),
                label: 'Continuar',
                fullWidth: true,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('secondary')), findsOneWidget);
    expect(find.byKey(const Key('primary')), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const Key('primary'))).dy,
      lessThan(600),
    );
    expect(find.text('Fila 19'), findsOneWidget);
  });

  testWidgets('pie sigue el inset del teclado en el mismo frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(
        body: const Text('Contenido'),
        footer: AppButton.filled(
          key: const Key('primary'),
          label: 'Continuar',
          onPressed: () {},
        ),
      ),
    );
    final restingBottom = tester
        .getBottomRight(find.byKey(const Key('primary')))
        .dy;

    await tester.pumpWidget(
      host(
        bottomInset: 280,
        body: const Text('Contenido'),
        footer: AppButton.filled(
          key: const Key('primary'),
          label: 'Continuar',
          onPressed: () {},
        ),
      ),
    );

    final keyboardBottom = tester
        .getBottomRight(find.byKey(const Key('primary')))
        .dy;
    expect(keyboardBottom, lessThanOrEqualTo(520));
    expect(restingBottom - keyboardBottom, closeTo(280, 0.1));
  });

  testWidgets('viewport reservado conserva la altura con contenido variable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildHost(double bodyHeight) => host(
      bodyViewportFraction: 0.68,
      body: SizedBox(height: bodyHeight),
      footer: AppButton.filled(label: 'Continuar', onPressed: () {}),
    );

    await tester.pumpWidget(buildHost(80));
    final compactHeight = tester
        .getSize(find.byKey(const Key('wizard.sheet')))
        .height;

    await tester.pumpWidget(buildHost(1200));
    final longHeight = tester
        .getSize(find.byKey(const Key('wizard.sheet')))
        .height;

    expect(longHeight, compactHeight);
  });

  testWidgets(
    'transición inline releva elementos sin hitboxes ni planos visibles juntos',
    (tester) async {
      var step = 1;
      var direction = AppWizardStepDirection.forward;
      late StateSetter update;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return AppWizardInlineTransition(
                  direction: direction,
                  child: SizedBox(
                    key: ValueKey<int>(step),
                    width: 240,
                    height: 120,
                    child: Text('Paso $step'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      update(() {
        direction = AppWizardStepDirection.forward;
        step = 2;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final first = find.byKey(const ValueKey<int>(1));
      final second = find.byKey(const ValueKey<int>(2));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.ancestor(of: first, matching: find.byType(IgnorePointer)),
            )
            .any((widget) => widget.ignoring),
        isTrue,
      );
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.ancestor(of: second, matching: find.byType(IgnorePointer)),
            )
            .any((widget) => widget.ignoring),
        isTrue,
      );

      double transitionOpacity(Finder child) => tester
          .widget<Opacity>(
            find.ancestor(of: child, matching: find.byType(Opacity)).first,
          )
          .opacity;

      expect(transitionOpacity(first), greaterThan(0));
      expect(transitionOpacity(second), 0);

      await tester.pump(const Duration(milliseconds: 70));
      expect(transitionOpacity(first), 0);
      expect(transitionOpacity(second), greaterThan(0));

      await tester.pumpAndSettle();
      expect(first, findsNothing);
      expect(second, findsOneWidget);
      expect(
        tester
            .widgetList<IgnorePointer>(
              find.ancestor(of: second, matching: find.byType(IgnorePointer)),
            )
            .every((widget) => !widget.ignoring),
        isTrue,
      );
    },
  );
}
