import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_color_swatch_picker.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/core/design/widgets/app_toggle_row.dart';
import 'package:ataulfo/features/public_catalog/domain/entities/catalog_appearance.dart';
import 'package:ataulfo/features/public_catalog/domain/entities/public_catalog_settings.dart';
import 'package:ataulfo/features/public_catalog/domain/failures/public_catalog_failure.dart';
import 'package:ataulfo/features/public_catalog/presentation/bloc/public_catalog_cubit.dart';
import 'package:ataulfo/features/public_catalog/presentation/pages/public_catalog_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<PublicCatalogState>
    implements PublicCatalogCubit {}

PublicCatalogState _loaded({
  bool enabled = true,
  String? slug = 'tacos',
  String? url = 'https://ataulfo.app/tacos',
  CatalogDesign design = CatalogDesign.carta,
  CatalogAccent accent = CatalogAccent.mango,
}) => PublicCatalogState(
  status: PublicCatalogStatus.loaded,
  settings: PublicCatalogSettings(
    enabled: enabled,
    slug: slug,
    url: url,
    design: design,
    accent: accent,
  ),
  loadFailure: null,
  saving: false,
  saveFailure: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(CatalogDesign.carta);
    registerFallbackValue(CatalogAccent.mango);
  });

  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());

  void stubSave() {
    when(
      () => cubit.save(
        enabled: any(named: 'enabled'),
        slug: any(named: 'slug'),
        design: any(named: 'design'),
        accent: any(named: 'accent'),
      ),
    ).thenAnswer((_) async {});
  }

  Future<void> pump(WidgetTester tester) async {
    // Surface alta: la página con la sección Apariencia rebasa el viewport por
    // defecto; con altura amplia el ListView construye todas las filas (incl.
    // swatches y botón), así los taps no fallan por celdas no construidas.
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<PublicCatalogCubit>.value(
          value: cubit,
          child: const PublicCatalogPage(),
        ),
      ),
    );
  }

  testWidgets('cargado usa componentes del sistema de diseño', (tester) async {
    when(() => cubit.state).thenReturn(_loaded());
    await pump(tester);
    expect(find.byType(AppToggleRow), findsOneWidget);
    expect(find.byType(AppSwitch), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byKey(const Key('public_catalog.save')), findsOneWidget);
    // Nada de Material crudo que rompa la consistencia visual.
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('cargando → AppLoadingIndicator', (tester) async {
    when(() => cubit.state).thenReturn(const PublicCatalogState.loading());
    await pump(tester);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('error → AppErrorState con reintentar', (tester) async {
    when(() => cubit.state).thenReturn(
      const PublicCatalogState(
        status: PublicCatalogStatus.error,
        settings: null,
        loadFailure: PublicCatalogNetworkFailure(),
        saving: false,
        saveFailure: null,
      ),
    );
    when(() => cubit.load()).thenAnswer((_) async {});
    await pump(tester);
    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('guardar dispara cubit.save con toggle y slug', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(_loaded(enabled: false, slug: '', url: null));
    stubSave();
    await pump(tester);

    await tester.tap(find.byKey(const Key('public_catalog.enabled')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('public_catalog.slug')),
      'mi-tienda',
    );
    await tester.tap(find.byKey(const Key('public_catalog.save')));
    await tester.pump();

    verify(
      () => cubit.save(
        enabled: true,
        slug: 'mi-tienda',
        design: CatalogDesign.carta,
        accent: CatalogAccent.mango,
      ),
    ).called(1);
  });

  testWidgets('Apariencia renderiza los 3 diseños y los 13 colores', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(_loaded());
    await pump(tester);
    for (final d in CatalogDesign.values) {
      expect(
        find.byKey(Key('public_catalog.design.${d.wire}')),
        findsOneWidget,
      );
    }
    expect(find.byType(AppColorSwatchPicker), findsOneWidget);
    for (final a in CatalogAccent.values) {
      expect(
        find.byKey(Key('public_catalog.accent.${a.wire}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('elegir diseño y color los envía al guardar', (tester) async {
    when(() => cubit.state).thenReturn(_loaded());
    stubSave();
    await pump(tester);

    await tester.tap(find.byKey(const Key('public_catalog.design.membrete')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('public_catalog.accent.vino')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('public_catalog.save')));
    await tester.pump();

    verify(
      () => cubit.save(
        enabled: true,
        slug: 'tacos',
        design: CatalogDesign.membrete,
        accent: CatalogAccent.vino,
      ),
    ).called(1);
  });
}
