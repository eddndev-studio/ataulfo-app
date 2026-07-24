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
  }) {
    return MaterialApp(
      theme: AppDesignTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: bottomInset)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AppWizardSheet(body: body, footer: footer),
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

  testWidgets('pie respeta el teclado mediante sheetBottomInset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(
      tester.getBottomRight(find.byKey(const Key('primary'))).dy,
      lessThanOrEqualTo(520),
    );
  });
}
