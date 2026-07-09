import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/product_catalog_failure.dart';
import 'package:ataulfo/features/product_catalog/presentation/widgets/product_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _initial = Product(
  id: 'p1',
  kind: ProductKind.service,
  name: 'Asesoría',
  description: 'Una hora',
  category: 'Servicios',
  priceCents: 125000,
  priceDisplay: r'$1,250.00 MXN',
  mediaRef: '',
  active: true,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

final _initialConImagen = Product(
  id: 'p2',
  kind: ProductKind.product,
  name: 'Mango Ataulfo',
  description: 'Caja de 5 kg',
  category: 'Fruta',
  priceCents: 125000,
  priceDisplay: r'$1,250.00 MXN',
  mediaRef: 'ref/original.png',
  active: true,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

MediaAsset _asset(String ref) => MediaAsset(
  ref: ref,
  previewUrl: null,
  filename: 'foto.png',
  contentType: 'image/png',
  size: 1,
  createdAt: DateTime.utc(2026, 7, 1),
);

/// Captura de los argumentos del último submit.
class _Submitted {
  ProductKind? kind;
  String? name;
  String? description;
  String? category;
  int? priceCents;
  String? mediaRef;
  bool? active;
  int calls = 0;
  ProductCatalogFailure? result;
}

void main() {
  Future<_Submitted> pumpAndOpen(
    WidgetTester tester, {
    Product? initial,
    List<String> categories = const <String>[],
    Future<MediaAsset?> Function(BuildContext)? pickImage,
    ProductComposePhoto? composePhoto,
  }) async {
    final submitted = _Submitted();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ProductFormSheet.open(
                context,
                initial: initial,
                categories: categories,
                pickImage: pickImage,
                composePhoto: composePhoto,
                thumbLoader: (_, {asset}) async => null,
                onSubmit:
                    ({
                      required ProductKind kind,
                      required String name,
                      required String description,
                      required String category,
                      required int priceCents,
                      required String mediaRef,
                      required bool active,
                    }) async {
                      submitted
                        ..kind = kind
                        ..name = name
                        ..description = description
                        ..category = category
                        ..priceCents = priceCents
                        ..mediaRef = mediaRef
                        ..active = active
                        ..calls += 1;
                      return submitted.result;
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
    return submitted;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('product_form.save')));
    await tester.tap(find.byKey(const Key('product_form.save')));
    await tester.pumpAndSettle();
  }

  testWidgets('alta: campos presentes, sin switch de activo', (tester) async {
    await pumpAndOpen(tester);
    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(find.byKey(const Key('product_form.name')), findsOneWidget);
    expect(find.byKey(const Key('product_form.price')), findsOneWidget);
    expect(find.byKey(const Key('product_form.category')), findsOneWidget);
    expect(find.byKey(const Key('product_form.description')), findsOneWidget);
    expect(find.byKey(const Key('product_form.kind.product')), findsOneWidget);
    expect(find.byKey(const Key('product_form.kind.service')), findsOneWidget);
    expect(find.byKey(const Key('product_form.pick_image')), findsOneWidget);
    expect(find.byType(AppSwitch), findsNothing);
  });

  testWidgets('guardar sin nombre ⇒ error y sin submit', (tester) async {
    final submitted = await pumpAndOpen(tester);
    await save(tester);
    expect(find.byKey(const Key('product_form.error')), findsOneWidget);
    expect(submitted.calls, 0);
  });

  testWidgets('precio inválido ⇒ error y sin submit', (tester) async {
    final submitted = await pumpAndOpen(tester);
    await tester.enterText(find.byKey(const Key('product_form.name')), 'Tarta');
    await tester.enterText(find.byKey(const Key('product_form.price')), 'abc');
    await save(tester);
    expect(find.byKey(const Key('product_form.error')), findsOneWidget);
    expect(submitted.calls, 0);
  });

  testWidgets('submit válido convierte pesos a centavos y cierra', (
    tester,
  ) async {
    final submitted = await pumpAndOpen(tester);
    await tester.enterText(find.byKey(const Key('product_form.name')), 'Tarta');
    await tester.enterText(
      find.byKey(const Key('product_form.price')),
      '1,250.00',
    );
    await tester.enterText(
      find.byKey(const Key('product_form.category')),
      'Postres',
    );
    await tester.enterText(
      find.byKey(const Key('product_form.description')),
      'De temporada',
    );
    await save(tester);
    expect(submitted.calls, 1);
    expect(submitted.kind, ProductKind.product);
    expect(submitted.name, 'Tarta');
    expect(submitted.priceCents, 125000);
    expect(submitted.category, 'Postres');
    expect(submitted.description, 'De temporada');
    expect(submitted.mediaRef, '');
    expect(submitted.active, isTrue);
    // La hoja se cerró.
    expect(find.byKey(const Key('product_form.name')), findsNothing);
  });

  testWidgets('failure del backend ⇒ copy visible y la hoja sigue abierta', (
    tester,
  ) async {
    final submitted = await pumpAndOpen(tester);
    submitted.result = const ProductCatalogValidationFailure(
      'La imagen elegida ya no está en la galería.',
    );
    await tester.enterText(find.byKey(const Key('product_form.name')), 'Tarta');
    await save(tester);
    expect(
      find.text('La imagen elegida ya no está en la galería.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('product_form.name')), findsOneWidget);
  });

  testWidgets('403 ⇒ copy de permisos', (tester) async {
    final submitted = await pumpAndOpen(tester);
    submitted.result = const ProductCatalogForbiddenFailure();
    await tester.enterText(find.byKey(const Key('product_form.name')), 'Tarta');
    await save(tester);
    expect(find.text('No tienes permiso para esta acción.'), findsOneWidget);
  });

  testWidgets('edición: precarga campos, switch activo y kind', (tester) async {
    final submitted = await pumpAndOpen(tester, initial: _initial);
    expect(find.text('Editar producto'), findsOneWidget);
    expect(find.text('Asesoría'), findsOneWidget);
    expect(find.text('1,250.00'), findsOneWidget);
    expect(find.text('Una hora'), findsOneWidget);
    expect(find.byType(AppSwitch), findsOneWidget);

    await tester.ensureVisible(find.byType(AppSwitch));
    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    await save(tester);
    expect(submitted.calls, 1);
    expect(submitted.kind, ProductKind.service);
    expect(submitted.priceCents, 125000);
    expect(submitted.active, isFalse);
  });

  testWidgets('elegir SERVICIO manda kind service', (tester) async {
    final submitted = await pumpAndOpen(tester);
    await tester.tap(find.byKey(const Key('product_form.kind.service')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('product_form.name')),
      'Asesoría',
    );
    await save(tester);
    expect(submitted.kind, ProductKind.service);
  });

  testWidgets('sugerencias de categoría llenan el campo', (tester) async {
    await pumpAndOpen(tester, categories: const <String>['Fruta', 'Postres']);
    await tester.tap(
      find.byKey(const Key('product_form.category_suggestion.Postres')),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('product_form.category')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, 'Postres');
  });

  testWidgets('imagen: elegir, enviar el ref y quitar', (tester) async {
    final submitted = await pumpAndOpen(
      tester,
      pickImage: (_) async => _asset('tenant/org/media/m9.png'),
    );
    await tester.tap(find.byKey(const Key('product_form.pick_image')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product_form.remove_image')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('product_form.name')), 'Tarta');
    await save(tester);
    expect(submitted.mediaRef, 'tenant/org/media/m9.png');
  });

  testWidgets('quitar imagen vuelve al estado sin ref', (tester) async {
    final submitted = await pumpAndOpen(
      tester,
      pickImage: (_) async => _asset('tenant/org/media/m9.png'),
    );
    await tester.tap(find.byKey(const Key('product_form.pick_image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product_form.remove_image')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product_form.pick_image')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('product_form.name')), 'Tarta');
    await save(tester);
    expect(submitted.mediaRef, '');
  });

  testWidgets('edición con imagen + seam ⇒ acción «Mejorar foto con IA»', (
    tester,
  ) async {
    await pumpAndOpen(
      tester,
      initial: _initialConImagen,
      composePhoto: (_, _) async => null,
    );
    expect(find.byKey(const Key('product_form.compose_photo')), findsOneWidget);
  });

  testWidgets('sin imagen del servidor, en alta o sin seam ⇒ sin acción', (
    tester,
  ) async {
    // Cada caso arranca de un árbol limpio: reusar el MaterialApp dejaría la
    // hoja anterior abierta y los asserts mirarían la hoja equivocada.
    Future<void> reset() async {
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    }

    // Alta (aun con seam).
    await pumpAndOpen(tester, composePhoto: (_, _) async => null);
    expect(find.byKey(const Key('product_form.compose_photo')), findsNothing);
    await reset();
    // Edición de un producto SIN imagen.
    await pumpAndOpen(
      tester,
      initial: _initial,
      composePhoto: (_, _) async => null,
    );
    expect(find.byKey(const Key('product_form.compose_photo')), findsNothing);
    await reset();
    // Edición con imagen pero sin seam cableado.
    await pumpAndOpen(tester, initial: _initialConImagen);
    expect(find.byKey(const Key('product_form.compose_photo')), findsNothing);
    // El resto del form sí está (la hoja abrió de verdad).
    expect(find.byKey(const Key('product_form.name')), findsOneWidget);
  });

  testWidgets('aceptar una composición actualiza el ref que viaja al guardar', (
    tester,
  ) async {
    Product? received;
    final submitted = await pumpAndOpen(
      tester,
      initial: _initialConImagen,
      composePhoto: (_, product) async {
        received = product;
        return 'ref/compuesta.png';
      },
    );
    await tester.ensureVisible(
      find.byKey(const Key('product_form.compose_photo')),
    );
    await tester.tap(find.byKey(const Key('product_form.compose_photo')));
    await tester.pumpAndSettle();
    expect(received, _initialConImagen);

    await save(tester);
    expect(submitted.calls, 1);
    expect(submitted.mediaRef, 'ref/compuesta.png');
  });

  testWidgets('cerrar la hoja de composición sin aceptar no toca el ref', (
    tester,
  ) async {
    final submitted = await pumpAndOpen(
      tester,
      initial: _initialConImagen,
      composePhoto: (_, _) async => null,
    );
    await tester.ensureVisible(
      find.byKey(const Key('product_form.compose_photo')),
    );
    await tester.tap(find.byKey(const Key('product_form.compose_photo')));
    await tester.pumpAndSettle();
    await save(tester);
    expect(submitted.mediaRef, 'ref/original.png');
  });

  testWidgets('la hoja reserva el espacio del teclado (sheetBottomInset)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 300),
              viewPadding: EdgeInsets.zero,
              padding: EdgeInsets.zero,
            ),
            // Modo edición: sin autofocus, así no hay timer de cursor que
            // haga time-out el settle.
            child: Material(
              child: ProductFormSheet(
                initial: _initial,
                thumbLoader: (_, {asset}) async => null,
                onSubmit:
                    ({
                      required ProductKind kind,
                      required String name,
                      required String description,
                      required String category,
                      required int priceCents,
                      required String mediaRef,
                      required bool active,
                    }) async => null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final padding = tester.widget<Padding>(
      find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding is EdgeInsets &&
            (w.padding as EdgeInsets).left == AppTokens.sp5 &&
            (w.padding as EdgeInsets).top == AppTokens.sp2,
      ),
    );
    expect((padding.padding as EdgeInsets).bottom, greaterThanOrEqualTo(300));
  });
}
