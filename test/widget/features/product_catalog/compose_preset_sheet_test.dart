import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/composition_failure.dart';
import 'package:ataulfo/features/product_catalog/presentation/widgets/compose_preset_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captura del último onCreate.
class _Created {
  String? preset;
  bool? premium;
  int calls = 0;
  CompositionFailure? result;
}

void main() {
  Future<_Created> pumpAndOpen(WidgetTester tester) async {
    final created = _Created();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ComposePresetSheet.open(
                context,
                onCreate:
                    ({required String preset, required bool premium}) async {
                      created
                        ..preset = preset
                        ..premium = premium
                        ..calls += 1;
                      return created.result;
                    },
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return created;
  }

  Future<void> create(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('compose_preset.create')));
    await tester.tap(find.byKey(const Key('compose_preset.create')));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra las 5 escenas con sus rótulos fijos', (tester) async {
    await pumpAndOpen(tester);
    expect(find.text('Estudio blanco'), findsOneWidget);
    expect(find.text('Mármol'), findsOneWidget);
    expect(find.text('Madera cálida'), findsOneWidget);
    expect(find.text('Degradado suave'), findsOneWidget);
    expect(find.text('Exterior luminoso'), findsOneWidget);
    expect(find.byKey(const Key('compose_preset.premium')), findsOneWidget);
  });

  testWidgets('crear sin tocar nada ⇒ estudio-blanco estándar y cierra', (
    tester,
  ) async {
    final created = await pumpAndOpen(tester);
    await create(tester);
    expect(created.calls, 1);
    expect(created.preset, 'estudio-blanco');
    expect(created.premium, isFalse);
    expect(find.byKey(const Key('compose_preset.create')), findsNothing);
  });

  testWidgets('elegir escena + premium viaja al onCreate', (tester) async {
    final created = await pumpAndOpen(tester);
    await tester.tap(find.byKey(const Key('compose_preset.card.marmol')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('compose_preset.premium')));
    await tester.tap(find.byKey(const Key('compose_preset.premium')));
    await tester.pumpAndSettle();
    await create(tester);
    expect(created.preset, 'marmol');
    expect(created.premium, isTrue);
  });

  testWidgets('rechazo del backend ⇒ copy visible y la hoja sigue abierta', (
    tester,
  ) async {
    final created = await pumpAndOpen(tester);
    created.result = const CompositionRejectedFailure(
      'Alcanzaste el tope de imágenes de tu plan este mes.',
    );
    await create(tester);
    expect(
      find.text('Alcanzaste el tope de imágenes de tu plan este mes.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('compose_preset.create')), findsOneWidget);
  });

  testWidgets('failure sin mensaje ⇒ copy genérico, jamás el código crudo', (
    tester,
  ) async {
    final created = await pumpAndOpen(tester);
    created.result = const CompositionUnavailableFailure();
    await create(tester);
    expect(
      find.text(
        'La mejora de fotos no está disponible por ahora. '
        'Inténtalo más tarde.',
      ),
      findsOneWidget,
    );
  });
}
