import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_switch.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';
import 'package:ataulfo/core/design/widgets/app_toggle_row.dart';
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
}) => PublicCatalogState(
  status: PublicCatalogStatus.loaded,
  settings: PublicCatalogSettings(enabled: enabled, slug: slug, url: url),
  loadFailure: null,
  saving: false,
  saveFailure: null,
);

void main() {
  late _MockCubit cubit;

  setUp(() => cubit = _MockCubit());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<PublicCatalogCubit>.value(
        value: cubit,
        child: const PublicCatalogPage(),
      ),
    ),
  );

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
    when(
      () => cubit.save(
        enabled: any(named: 'enabled'),
        slug: any(named: 'slug'),
      ),
    ).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.byKey(const Key('public_catalog.enabled')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('public_catalog.slug')),
      'mi-tienda',
    );
    await tester.tap(find.byKey(const Key('public_catalog.save')));
    await tester.pump();

    verify(() => cubit.save(enabled: true, slug: 'mi-tienda')).called(1);
  });
}
