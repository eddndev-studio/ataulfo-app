import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_header_card.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_swatch_icon.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/labels/presentation/pages/labels_admin_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  late _MockBloc bloc;
  late _MockAuthBloc authBloc;

  setUp(() {
    bloc = _MockBloc();
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
  });

  void seed(LabelsAdminState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<LabelsAdminState>.empty(),
      initialState: state,
    );
  }

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<LabelsAdminBloc>.value(value: bloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: const Scaffold(body: LabelsAdminPage()),
    ),
  );

  const twoLabels = LabelsAdminLoaded(
    labels: <Label>[
      Label(id: '1', name: 'VIP', color: '#7c3aed', description: 'Oro'),
      Label(id: '2', name: 'Soporte', color: '#22c55e', description: ''),
    ],
    isRefreshing: false,
  );

  testWidgets('Loading → spinner canónico del kit', (tester) async {
    seed(const LabelsAdminLoading());
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('Loaded monta el header rico de sección (paridad con tabs)', (
    tester,
  ) async {
    seed(twoLabels);
    await tester.pumpWidget(host());

    expect(find.byType(AppHeaderCard), findsOneWidget);
    expect(find.text('Etiquetas'), findsOneWidget);
    // El saludo viene de la sesión (parte local del email capitalizada).
    expect(find.textContaining('Op'), findsWidgets);
  });

  testWidgets('Loaded con etiquetas → nombres + glifo tintado por etiqueta', (
    tester,
  ) async {
    seed(twoLabels);
    await tester.pumpWidget(host());
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Oro'), findsOneWidget);
    // La identidad cromática deja de ser un dot de 16px: glifo tintado 44px.
    expect(find.byType(AppSwatchIcon), findsNWidgets(2));
  });

  testWidgets('el listado es UNA sola card con filas separadas por divider', (
    tester,
  ) async {
    seed(twoLabels);
    await tester.pumpWidget(host());
    // Idioma de hubs/ajustes: una card apila las filas, no una card por item.
    expect(find.byType(AppCard), findsOneWidget);
    // 2 etiquetas ⇒ 1 divider hairline del kit entre filas.
    final dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
    expect(dividers.length, 1);
    expect(dividers.first.color, AppTokens.divider);
  });

  testWidgets('buscador filtra por nombre (client-side)', (tester) async {
    seed(twoLabels);
    await tester.pumpWidget(host());

    await tester.enterText(find.byKey(const Key('labels_admin.search')), 'vip');
    await tester.pump();

    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Soporte'), findsNothing);
  });

  testWidgets('búsqueda sin coincidencias → aviso no_results', (tester) async {
    seed(twoLabels);
    await tester.pumpWidget(host());

    await tester.enterText(find.byKey(const Key('labels_admin.search')), 'zzz');
    await tester.pump();

    expect(find.byKey(const Key('labels_admin.no_results')), findsOneWidget);
  });

  testWidgets('cada fila tiene ripple propio (InkWell con onTap)', (
    tester,
  ) async {
    seed(
      const LabelsAdminLoaded(
        labels: <Label>[
          Label(id: '1', name: 'VIP', color: '#7c3aed', description: ''),
        ],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());

    // El feedback táctil vive por fila: al colapsar las etiquetas en una card,
    // cada fila es su propio InkWell tap-target (la card ya no es tappable).
    final row = tester.widget<InkWell>(
      find.byKey(const Key('labels_admin.tile.1')),
    );
    expect(row.onTap, isNotNull);
  });

  testWidgets('Loaded vacío → empty state SIN perder el header ni el refresh', (
    tester,
  ) async {
    seed(const LabelsAdminLoaded(labels: <Label>[], isRefreshing: false));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('labels_admin.empty')), findsOneWidget);
    expect(find.byType(AppHeaderCard), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    // Sin etiquetas no hay qué buscar: el campo no se monta.
    expect(find.byKey(const Key('labels_admin.search')), findsNothing);
  });

  testWidgets('Failed → AppErrorState + reintentar despacha LoadRequested', (
    tester,
  ) async {
    seed(const LabelsAdminFailed(LabelsServerFailure()));
    await tester.pumpWidget(host());
    // El error es el primitivo canónico del kit (misma anatomía sobria).
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.byKey(const Key('labels_admin.error')), findsOneWidget);
    // El copy por tipo de fallo se conserva.
    expect(find.text('No pudimos cargar las etiquetas.'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    verify(() => bloc.add(const LabelsAdminLoadRequested())).called(1);
  });

  testWidgets('Failed de red → copy honesto de conexión', (tester) async {
    seed(const LabelsAdminFailed(LabelsNetworkFailure()));
    await tester.pumpWidget(host());
    expect(
      find.text('Sin conexión. Revisa tu red e inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('tocar una etiqueta abre la hoja de edición', (tester) async {
    seed(
      const LabelsAdminLoaded(
        labels: <Label>[
          Label(id: '1', name: 'VIP', color: '#7c3aed', description: ''),
        ],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('VIP'));
    await tester.pumpAndSettle();
    expect(find.text('Editar etiqueta'), findsOneWidget);
  });

  testWidgets('el scroll despeja el FAB del shell al fondo', (tester) async {
    when(() => bloc.state).thenReturn(
      const LabelsAdminLoaded(
        labels: <Label>[
          Label(id: '1', name: 'VIP', color: '#7c3aed', description: ''),
        ],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());

    final padding = tester.widget<Padding>(
      find.byKey(const Key('labels_admin.content_padding')),
    );
    final resolved = padding.padding.resolve(TextDirection.ltr);
    expect(resolved.bottom, greaterThanOrEqualTo(AppTokens.fabClearance));
  });
}
