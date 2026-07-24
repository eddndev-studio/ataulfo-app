import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:ataulfo/features/product_catalog/presentation/bloc/product_catalog_cubit.dart';
import 'package:ataulfo/features/product_catalog/presentation/pages/product_catalog_page.dart';
import 'package:ataulfo/features/product_catalog/presentation/widgets/product_catalog_fab.dart';
import 'package:ataulfo/features/product_catalog/presentation/widgets/product_form_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<ProductCatalogState>
    implements ProductCatalogCubit {}

Product _p({String id = 'p1', String category = 'Fruta'}) => Product(
  id: id,
  kind: ProductKind.product,
  name: 'Mango Ataulfo',
  description: '',
  category: category,
  priceCents: 0,
  priceDisplay: '',
  mediaRef: '',
  active: true,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

ProductCatalogState _state({
  ProductCatalogStatus status = ProductCatalogStatus.loaded,
  List<Product> items = const <Product>[],
  List<String> categories = const <String>[],
  String query = '',
  String? category,
  ProductKind? kind,
}) => ProductCatalogState(
  status: status,
  items: items,
  categories: categories,
  query: query,
  category: category,
  kind: kind,
  failure: null,
  mutating: false,
);

void main() {
  late _MockCubit cubit;

  setUp(() {
    cubit = _MockCubit();
    when(() => cubit.setQuery(any())).thenAnswer((_) async {});
    when(cubit.load).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {ProductComposePhoto? composePhoto}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: BlocProvider<ProductCatalogCubit>.value(
            value: cubit,
            child: Scaffold(
              body: ProductCatalogPage(
                pickImage: (_) async => null,
                thumbLoader: (_, {asset}) async => null,
                composePhoto: composePhoto,
              ),
              floatingActionButton: ProductCatalogFab(
                pickImage: (_) async => null,
                thumbLoader: (_, {asset}) async => null,
              ),
            ),
          ),
        ),
      );

  testWidgets('loading → spinner (el buscador sigue montado)', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(_state(status: ProductCatalogStatus.loading));
    await pump(tester);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(
      find.byKey(const Key('product_catalog.search_field')),
      findsOneWidget,
    );
    final search = tester.widget<AppSearchField>(
      find.byKey(const Key('product_catalog.search_field')),
    );
    expect(search.hint, 'Buscar por nombre o descripción…');
  });

  testWidgets('error → estado de error con retry que recarga', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(_state(status: ProductCatalogStatus.error));
    await pump(tester);
    expect(find.byType(AppErrorState), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    verify(cubit.load).called(1);
  });

  testWidgets('cargado con items → tarjetas', (tester) async {
    when(() => cubit.state).thenReturn(
      _state(
        items: <Product>[
          _p(),
          _p(id: 'p2'),
        ],
      ),
    );
    await pump(tester);
    expect(find.byKey(const Key('product_catalog.card.p1')), findsOneWidget);
    expect(find.byKey(const Key('product_catalog.card.p2')), findsOneWidget);
  });

  testWidgets('catálogo vacío sin filtros → empty state de arranque', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(_state());
    await pump(tester);
    expect(find.byKey(const Key('product_catalog.empty')), findsOneWidget);
  });

  testWidgets('búsqueda sin resultados → sin resultados', (tester) async {
    when(() => cubit.state).thenReturn(_state(query: 'nada'));
    await pump(tester);
    expect(find.byKey(const Key('product_catalog.no_results')), findsOneWidget);
  });

  testWidgets('chips de categoría salen del estado y disparan setCategory', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      _state(categories: <String>['Fruta', 'Postres'], items: <Product>[_p()]),
    );
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('product_catalog.category_chip.Postres')),
    );
    verify(() => cubit.setCategory('Postres')).called(1);
  });

  testWidgets('chip de categoría seleccionado se destoggle a null', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(_state(categories: <String>['Fruta'], category: 'Fruta'));
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('product_catalog.category_chip.Fruta')),
    );
    verify(() => cubit.setCategory(null)).called(1);
  });

  testWidgets('chip de kind dispara setKind', (tester) async {
    when(() => cubit.state).thenReturn(_state(items: <Product>[_p()]));
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('product_catalog.kind_chip.service')),
    );
    verify(() => cubit.setKind(ProductKind.service)).called(1);
  });

  testWidgets('chip de kind seleccionado se destoggle a null', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(_state(items: <Product>[_p()], kind: ProductKind.service));
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('product_catalog.kind_chip.service')),
    );
    verify(() => cubit.setKind(null)).called(1);
  });

  testWidgets('el buscador debouncea ~350 ms antes de setQuery', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(_state(items: <Product>[_p()]));
    await pump(tester);
    await tester.enterText(
      find.byKey(const Key('product_catalog.search_field')),
      'mango',
    );
    await tester.pump(const Duration(milliseconds: 200));
    verifyNever(() => cubit.setQuery(any()));
    await tester.pump(const Duration(milliseconds: 200));
    verify(() => cubit.setQuery('mango')).called(1);
  });

  testWidgets('tap en tarjeta abre la edición precargada', (tester) async {
    when(() => cubit.state).thenReturn(_state(items: <Product>[_p()]));
    await pump(tester);
    await tester.tap(find.byKey(const Key('product_catalog.card.p1')));
    await tester.pumpAndSettle();
    expect(find.text('Editar producto'), findsOneWidget);
    expect(find.text('Mango Ataulfo'), findsWidgets);
  });

  testWidgets('el FAB abre el alta', (tester) async {
    when(() => cubit.state).thenReturn(_state());
    await pump(tester);
    await tester.tap(find.byKey(const Key('product_catalog.fab')));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);
  });

  testWidgets('aceptar una composición desde la edición recarga el catálogo', (
    tester,
  ) async {
    final conImagen = Product(
      id: 'p1',
      kind: ProductKind.product,
      name: 'Mango Ataulfo',
      description: '',
      category: 'Fruta',
      priceCents: 0,
      priceDisplay: '',
      mediaRef: 'ref/original.png',
      active: true,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    when(() => cubit.state).thenReturn(_state(items: <Product>[conImagen]));
    var seamCalls = 0;
    await pump(
      tester,
      composePhoto: (_, _) async {
        seamCalls++;
        return 'ref/compuesta.png';
      },
    );
    await tester.tap(find.byKey(const Key('product_catalog.card.p1')));
    await tester.pumpAndSettle();
    // «Mejorar foto con IA» vive en el paso 2 del wizard.
    await tester.tap(find.byKey(const Key('product_form.next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('product_form.compose_photo')),
    );
    await tester.tap(find.byKey(const Key('product_form.compose_photo')));
    await tester.pumpAndSettle();
    expect(seamCalls, 1);
    // La foto del producto ya cambió en el backend: el listado no espera al
    // guardado del form para refrescarse.
    verify(cubit.load).called(1);
  });
}
