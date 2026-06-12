import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_header_card.dart';
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

  testWidgets('Loading → spinner', (tester) async {
    seed(const LabelsAdminLoading());
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

  testWidgets('el tile usa el onTap del AppCard (ripple del DS)', (
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

    // El feedback táctil viene del InkWell interno del AppCard; un
    // GestureDetector externo no da ripple y deja el tap "muerto" al ojo.
    final card = tester.widget<AppCard>(find.byType(AppCard).first);
    expect(card.onTap, isNotNull);
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

  testWidgets('Failed → error + reintentar despacha LoadRequested', (
    tester,
  ) async {
    seed(const LabelsAdminFailed(LabelsServerFailure()));
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('labels_admin.error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('labels_admin.retry')));
    verify(() => bloc.add(const LabelsAdminLoadRequested())).called(1);
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
}
