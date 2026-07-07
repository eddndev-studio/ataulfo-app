import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/auth/presentation/bloc/rename_org_cubit.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';
import 'package:ataulfo/features/org_customization/domain/entities/org_branding.dart';
import 'package:ataulfo/features/org_customization/presentation/bloc/org_customization_cubit.dart';
import 'package:ataulfo/features/org_customization/presentation/pages/org_customization_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<OrgCustomizationState>
    implements OrgCustomizationCubit {}

class _MockRenameCubit extends MockCubit<RenameOrgState>
    implements RenameOrgCubit {}

const _base = OrgBranding(
  configured: false,
  customTex: false,
  hasLogo: false,
  logoUrl: '',
  logoContentType: '',
);

const _withLogo = OrgBranding(
  configured: true,
  customTex: false,
  hasLogo: true,
  logoUrl: '',
  logoContentType: 'image/png',
);

const _withCustomTex = OrgBranding(
  configured: true,
  customTex: true,
  hasLogo: false,
  logoUrl: '',
  logoContentType: '',
);

MediaAsset _asset(String ct) => MediaAsset(
  ref: 'tenant/org-1/media/l1.png',
  previewUrl: null,
  filename: 'logo.png',
  contentType: ct,
  size: 1024,
  createdAt: DateTime.utc(2026),
);

void main() {
  late _MockCubit cubit;
  late _MockRenameCubit renameCubit;

  setUp(() {
    cubit = _MockCubit();
    renameCubit = _MockRenameCubit();
    when(() => renameCubit.state).thenReturn(const RenameOrgIdle());
  });

  Future<void> pump(WidgetTester tester, {MediaAsset? picked}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<OrgCustomizationCubit>.value(value: cubit),
            BlocProvider<RenameOrgCubit>.value(value: renameCubit),
          ],
          child: Scaffold(
            body: OrgCustomizationPage(pickLogo: (_) async => picked),
          ),
        ),
      ),
    );
  }

  testWidgets('cargando → spinner', (tester) async {
    when(() => cubit.state).thenReturn(const OrgCustomizationLoading());
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Ready → nombre de la org + acciones', (tester) async {
    when(() => cubit.state).thenReturn(
      const OrgCustomizationReady(orgName: 'App Master', branding: _base),
    );
    await pump(tester);

    expect(find.text('App Master'), findsOneWidget);
    expect(find.byKey(const Key('org_customization.rename')), findsOneWidget);
    expect(
      find.byKey(const Key('org_customization.pick_logo')),
      findsOneWidget,
    );
    // Sin marca guardada no hay nada que restablecer.
    expect(find.byKey(const Key('org_customization.reset')), findsNothing);
  });

  testWidgets('con marca guardada → aparece Restablecer', (tester) async {
    when(() => cubit.state).thenReturn(
      const OrgCustomizationReady(orgName: 'App Master', branding: _withLogo),
    );
    await pump(tester);
    expect(find.byKey(const Key('org_customization.reset')), findsOneWidget);
  });

  testWidgets('elegir logo PNG → setLogo con el ref BARE', (tester) async {
    when(() => cubit.state).thenReturn(
      const OrgCustomizationReady(orgName: 'App Master', branding: _base),
    );
    when(() => cubit.setLogo(any())).thenAnswer((_) async {});
    await pump(tester, picked: _asset('image/png'));

    await tester.tap(find.byKey(const Key('org_customization.pick_logo')));
    await tester.pumpAndSettle();

    verify(() => cubit.setLogo('tenant/org-1/media/l1.png')).called(1);
  });

  testWidgets('elegir un tipo no incluible → aviso y NO se guarda', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const OrgCustomizationReady(orgName: 'App Master', branding: _base),
    );
    await pump(tester, picked: _asset('image/webp'));

    await tester.tap(find.byKey(const Key('org_customization.pick_logo')));
    await tester.pumpAndSettle();

    expect(find.text('El logo debe ser PNG o JPEG.'), findsOneWidget);
    verifyNever(() => cubit.setLogo(any()));
  });

  testWidgets('con tex de autor → confirma antes de reemplazar', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const OrgCustomizationReady(
        orgName: 'App Master',
        branding: _withCustomTex,
      ),
    );
    when(() => cubit.setLogo(any())).thenAnswer((_) async {});
    await pump(tester, picked: _asset('image/png'));

    await tester.tap(find.byKey(const Key('org_customization.pick_logo')));
    await tester.pumpAndSettle();

    // El asistente guardó una plantilla personalizada: nada se pisa sin
    // confirmación explícita.
    verifyNever(() => cubit.setLogo(any()));
    expect(
      find.byKey(const Key('org_customization.replace_confirm')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('org_customization.replace_confirm')),
    );
    await tester.pumpAndSettle();
    verify(() => cubit.setLogo('tenant/org-1/media/l1.png')).called(1);
  });

  testWidgets('restablecer → confirma y llama reset', (tester) async {
    when(() => cubit.state).thenReturn(
      const OrgCustomizationReady(orgName: 'App Master', branding: _withLogo),
    );
    when(() => cubit.reset()).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.byKey(const Key('org_customization.reset')));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.reset());

    await tester.tap(find.byKey(const Key('org_customization.reset_confirm')));
    await tester.pumpAndSettle();
    verify(() => cubit.reset()).called(1);
  });
}
