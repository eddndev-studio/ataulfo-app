import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/billing/domain/entities/entitlement.dart';
import 'package:ataulfo/features/billing/domain/failures/billing_failure.dart';
import 'package:ataulfo/features/billing/domain/repositories/web_link_launcher.dart';
import 'package:ataulfo/features/billing/presentation/bloc/entitlement_bloc.dart';
import 'package:ataulfo/features/billing/presentation/pages/cuenta_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<EntitlementEvent, EntitlementState>
    implements EntitlementBloc {}

class _FakeLauncher implements WebLinkLauncher {
  final List<String> opened = <String>[];

  @override
  Future<void> open(String url) async => opened.add(url);
}

Entitlement _ent({
  String planCode = 'pro',
  String status = 'active',
  bool trialExpired = false,
  int creditsUsed = 12,
  int creditCap = 10000,
  bool withinQuota = true,
  bool quotaExceeded = false,
  List<String> features = const <String>['media_gallery'],
  ImageGenUsage? imageGen,
}) => Entitlement(
  planCode: planCode,
  status: status,
  trialExpired: trialExpired,
  creditsUsed: creditsUsed,
  creditCap: creditCap,
  withinQuota: withinQuota,
  quotaExceeded: quotaExceeded,
  storageUsedMb: 100,
  storageQuotaMb: 512,
  eligibleProviders: const <String>{'MINIMAX'},
  features: features,
  imageGen: imageGen,
);

void main() {
  late _MockBloc bloc;
  late _FakeLauncher launcher;

  setUp(() {
    bloc = _MockBloc();
    launcher = _FakeLauncher();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: BlocProvider<EntitlementBloc>.value(
        value: bloc,
        child: Scaffold(
          body: CuentaPage(webBaseUrl: 'https://web.test', launcher: launcher),
        ),
      ),
    ),
  );

  testWidgets('cargando → spinner', (tester) async {
    when(() => bloc.state).thenReturn(const EntitlementLoading());
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('activa → plan + pill Activo + consumo, sin banner', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(EntitlementLoaded(entitlement: _ent()));
    await pump(tester);

    expect(find.text('Pro'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'Activo'), findsOneWidget);
    expect(find.text('Créditos de IA'), findsOneWidget);
    expect(find.text('12 de 10000 este mes'), findsOneWidget);
    expect(find.text('100 MB de 512 MB'), findsOneWidget);
    // La tranquilidad de que los flujos deterministas nunca se pausan.
    expect(
      find.text(
        'Tus flujos y mensajes automáticos siempre funcionan, incluso '
        'con la IA en pausa.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cuenta.banner')), findsNothing);
  });

  testWidgets('trialing vigente → pill "En prueba"', (tester) async {
    when(() => bloc.state).thenReturn(
      EntitlementLoaded(
        entitlement: _ent(planCode: 'trial', status: 'trialing'),
      ),
    );
    await pump(tester);

    expect(find.text('Prueba'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'En prueba'), findsOneWidget);
  });

  testWidgets('prueba vencida → banner IA pausada con CTA a /precios', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      EntitlementLoaded(
        entitlement: _ent(
          planCode: 'trial',
          status: 'trialing',
          trialExpired: true,
        ),
      ),
    );
    await pump(tester);

    expect(find.byKey(const Key('cuenta.banner')), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'IA pausada'), findsOneWidget);
    expect(
      find.text(
        'Tu prueba terminó. Mejora tu plan para reactivar la IA de '
        'tus asistentes.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('cuenta.banner_cta')));
    await tester.pump();
    expect(launcher.opened, <String>['https://web.test/precios']);
  });

  testWidgets('sin media_gallery → la línea de almacenamiento no aparece', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      EntitlementLoaded(entitlement: _ent(features: const <String>[])),
    );
    await pump(tester);

    expect(find.text('Almacenamiento'), findsNothing);
    expect(find.text('100 MB de 512 MB'), findsNothing);
  });

  testWidgets('gestionar en la web → abre /cuenta del sitio', (tester) async {
    when(() => bloc.state).thenReturn(EntitlementLoaded(entitlement: _ent()));
    await pump(tester);

    await tester.tap(find.byKey(const Key('cuenta.manage_web')));
    await tester.pump();
    expect(launcher.opened, <String>['https://web.test/cuenta']);
  });

  testWidgets('falla dura → Reintentar re-dispara la carga', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const EntitlementFailed(BillingNetworkFailure()));
    await pump(tester);

    expect(find.text('No se pudo cargar tu plan.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cuenta.retry')));
    verify(() => bloc.add(const EntitlementLoadRequested())).called(1);
  });

  testWidgets('404 sin suscripción → copy propio + CTA a planes', (
    tester,
  ) async {
    // La org sin suscripción NO es un error de carga: es un estado del
    // producto con salida (contratar en la web).
    when(
      () => bloc.state,
    ).thenReturn(const EntitlementFailed(BillingNotFoundFailure()));
    await pump(tester);

    expect(find.text('Aún no tienes un plan configurado.'), findsOneWidget);
    expect(find.byKey(const Key('cuenta.retry')), findsNothing);

    await tester.tap(find.byKey(const Key('cuenta.no_plan_cta')));
    await tester.pump();
    expect(launcher.opened, <String>['https://web.test/precios']);
  });

  testWidgets('snapshot con imageGen → contador de imágenes con IA', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      EntitlementLoaded(
        entitlement: _ent(imageGen: const ImageGenUsage(used: 3, cap: 150)),
      ),
    );
    await pump(tester);

    expect(find.byKey(const Key('cuenta.image_gen')), findsOneWidget);
    expect(find.text('Imágenes con IA'), findsOneWidget);
    expect(find.text('3 de 150 este mes'), findsOneWidget);
  });

  testWidgets('snapshot SIN imageGen → sin contador (backend viejo no '
      'inventa ceros)', (tester) async {
    when(() => bloc.state).thenReturn(EntitlementLoaded(entitlement: _ent()));
    await pump(tester);

    expect(find.byKey(const Key('cuenta.image_gen')), findsNothing);
    expect(find.text('Imágenes con IA'), findsNothing);
  });
}
