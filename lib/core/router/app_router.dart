import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_catalog/domain/repositories/catalog_repository.dart';
import '../../features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/bots/domain/repositories/bots_repository.dart';
import '../../features/bots/presentation/bloc/bot_create_bloc.dart';
import '../../features/bots/presentation/bloc/bot_detail_bloc.dart';
import '../../features/bots/presentation/bloc/bots_bloc.dart';
import '../../features/bots/presentation/pages/bot_create_page.dart';
import '../../features/bots/presentation/pages/bot_detail_page.dart';
import '../../features/bots/presentation/pages/bot_template_picker_page.dart';
import '../../features/flows/domain/repositories/flows_repository.dart';
import '../../features/flows/presentation/bloc/flow_detail_bloc.dart';
import '../../features/flows/presentation/bloc/flows_bloc.dart';
import '../../features/flows/presentation/pages/flow_detail_page.dart';
import '../../features/memberships/domain/repositories/memberships_repository.dart';
import '../../features/memberships/presentation/bloc/memberships_bloc.dart';
import '../../features/memberships/presentation/pages/memberships_page.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/templates/domain/repositories/templates_repository.dart';
import '../../features/templates/presentation/bloc/template_create_bloc.dart';
import '../../features/templates/presentation/bloc/template_detail_bloc.dart';
import '../../features/templates/presentation/bloc/template_edit_bloc.dart';
import '../../features/templates/presentation/bloc/templates_bloc.dart';
import '../../features/templates/presentation/bloc/var_defs_bloc.dart';
import '../../features/templates/presentation/pages/template_create_page.dart';
import '../../features/templates/presentation/pages/template_detail_page.dart';
import '../../features/templates/presentation/pages/template_edit_page.dart';
import '../../features/triggers/domain/repositories/triggers_repository.dart';
import '../../features/triggers/presentation/bloc/triggers_bloc.dart';

/// Rutas de la app. La decisión de a qué ruta ir vive en el `redirect`
/// del GoRouter: lee el estado del `AuthBloc` global y mapea a `/`,
/// `/login` o `/home`. El Splash es un widget tonto.
///
/// `refreshListenable` se cabla al stream del bloc vía un `Listenable`
/// que invoca `notifyListeners()` en cada emisión. Cualquier transición
/// del estado de auth se traduce en una re-evaluación del redirect.
///
/// `/home` arma su propio `BotsBloc` page-scoped y dispara el primer load
/// al construirse. Cuando el shell con tabs aterrice, el bloc subirá al
/// nivel del shell para que la lista sobreviva al cambio de tab.
class AppRouter {
  AppRouter({
    required AuthBloc authBloc,
    required AuthRepository authRepository,
    required BotsRepository botsRepository,
    required TemplatesRepository templatesRepository,
    required FlowsRepository flowsRepository,
    required TriggersRepository triggersRepository,
    required MembershipsRepository membershipsRepository,
    required CatalogRepository catalogRepository,
  }) : _authBloc = authBloc,
       _authRepo = authRepository,
       _botsRepo = botsRepository,
       _templatesRepo = templatesRepository,
       _flowsRepo = flowsRepository,
       _triggersRepo = triggersRepository,
       _membershipsRepo = membershipsRepository,
       _catalogRepo = catalogRepository;

  final AuthBloc _authBloc;
  final AuthRepository _authRepo;
  final BotsRepository _botsRepo;
  final TemplatesRepository _templatesRepo;
  final FlowsRepository _flowsRepo;
  final TriggersRepository _triggersRepo;
  final MembershipsRepository _membershipsRepo;
  final CatalogRepository _catalogRepo;

  /// Observer compartido entre el Navigator del GoRouter y los list pages
  /// del shell. El GoRouter notifica push/pop sobre este observer; las
  /// list pages (Bots, Templates) se suscriben en didChangeDependencies
  /// y dispatchan su refresh cuando una sub-ruta encima cierra. Sin esto
  /// el operador tiene que pull-to-refresh tras crear/editar.
  final RouteObserver<PageRoute<dynamic>> _routeObserver =
      RouteObserver<PageRoute<dynamic>>();

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthBlocListenable(_authBloc),
    redirect: _redirect,
    observers: <NavigatorObserver>[_routeObserver],
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (context, _) => BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(_authRepo),
          child: LoginPage(
            onSucceeded: (_) {
              // El verify dispara la transición a Authenticated y el
              // redirect navega a /home. Los tokens los acaba de
              // persistir el AuthRepository.login(); el bloc los lee
              // a través de hasTokens() + me().
              _authBloc.add(const AuthCheckRequested());
            },
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, _) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<BotsBloc>(
              create: (_) =>
                  BotsBloc(_botsRepo)..add(const BotsLoadRequested()),
            ),
            BlocProvider<TemplatesBloc>(
              create: (_) =>
                  TemplatesBloc(_templatesRepo)
                    ..add(const TemplatesLoadRequested()),
            ),
          ],
          // Blocs page-scoped a nivel del shell: cambiar de tab no
          // rebuildea los providers y cada lista preserva estado
          // (Loaded, refresh, failures) entre Bots ⇄ Plantillas ⇄ Ajustes.
          // El routeObserver se atraviesa al shell para que ambos list
          // pages disparen su refresh al volver de una sub-ruta.
          child: ShellPage(routeObserver: _routeObserver),
        ),
      ),
      GoRoute(
        // Selector de plantilla para arrancar la creación de un bot desde
        // la tab Bots (sin plantilla previa). El `TemplatesBloc` se monta
        // page-scoped aquí -- no reusamos el del shell porque la ruta vive
        // fuera del subárbol de `/home`, así que el provider ascendente
        // no llega. Esto significa una segunda llamada GET /templates al
        // entrar al selector; la cache de RFC-0001 lo absorberá cuando
        // aterrice.
        //
        // DEBE ir antes de `/bots/:id` -- GoRouter matchea en orden de
        // declaración y `:id` capturaría `new` como ID válido, montando
        // el detalle con id="new" en lugar del selector.
        path: '/bots/new',
        builder: (context, _) => BlocProvider<TemplatesBloc>(
          create: (_) =>
              TemplatesBloc(_templatesRepo)
                ..add(const TemplatesLoadRequested()),
          child: Scaffold(
            appBar: AppBar(title: const Text('Elegir plantilla')),
            body: const BotTemplatePickerPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/bots/:id',
        builder: (context, state) {
          // El ID lo aporta el path param; el BotDetailBloc se construye
          // con ese ID y arranca cargando inmediato. Sin seed desde la
          // lista — la cache local (RFC-0001) será la que evite el flash
          // de spinner cuando aterrice.
          final id = state.pathParameters['id']!;
          return BlocProvider<BotDetailBloc>(
            create: (_) =>
                BotDetailBloc(repo: _botsRepo, id: id)
                  ..add(const BotDetailLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Detalle del bot')),
              body: const BotDetailPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/templates/new',
        builder: (context, _) => BlocProvider<TemplateCreateBloc>(
          create: (_) => TemplateCreateBloc(repo: _templatesRepo),
          child: Scaffold(
            appBar: AppBar(title: const Text('Crear plantilla')),
            body: const TemplateCreatePage(),
          ),
        ),
      ),
      GoRoute(
        path: '/templates/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TemplateDetailBloc>(
                create: (_) =>
                    TemplateDetailBloc(repo: _templatesRepo, id: id)
                      ..add(const TemplateDetailLoadRequested()),
              ),
              BlocProvider<VarDefsBloc>(
                create: (_) =>
                    VarDefsBloc(repo: _templatesRepo, templateId: id)
                      ..add(const VarDefsLoadRequested()),
              ),
              BlocProvider<FlowsBloc>(
                create: (_) =>
                    FlowsBloc(repo: _flowsRepo, templateId: id)
                      ..add(const FlowsLoadRequested()),
              ),
              BlocProvider<TriggersBloc>(
                create: (_) =>
                    TriggersBloc(repo: _triggersRepo, templateId: id)
                      ..add(const TriggersLoadRequested()),
              ),
            ],
            child: Scaffold(
              appBar: AppBar(title: const Text('Detalle de plantilla')),
              body: const TemplateDetailPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Editor completo: name + systemPrompt + AIConfig (provider,
        // model, temperature, thinking, contextMessages, enabled).
        // Page-scoped: dos blocs montados en paralelo — TemplateEditBloc
        // carga el template y CatalogBloc carga la tabla de modelos del
        // backend. Ambos disparan load al construirse; el form espera
        // a que ambos terminen antes de renderizar (Loading combinado).
        // Tras Succeeded, la página hace pushReplacement a
        // /templates/:id, así el back físico vuelve al listado sin
        // pasar por el form que ya cumplió. Subruta del id (path
        // /templates/:id/edit), no compite con /templates/new ni con
        // /templates/:id por orden de match.
        path: '/templates/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TemplateEditBloc>(
                create: (_) =>
                    TemplateEditBloc(repo: _templatesRepo, id: id)
                      ..add(const TemplateEditLoadRequested()),
              ),
              BlocProvider<CatalogBloc>(
                create: (_) =>
                    CatalogBloc(_catalogRepo)
                      ..add(const CatalogLoadRequested()),
              ),
            ],
            child: Scaffold(
              appBar: AppBar(title: const Text('Editar plantilla')),
              body: const TemplateEditPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Detalle de un flow (S11 F2) — read-only. Page-scoped:
        // `FlowDetailBloc` carga cabecera + steps en paralelo (Future.wait)
        // y emite Loaded/Failed. La ruta es de primer nivel, deep-linkable
        // (consistente con /templates/:id, /bots/:id). El back físico
        // vuelve al detalle de plantilla si se llegó vía tap del row de
        // Flujos, o al destino previo cuando entre por deep-link.
        path: '/flows/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<FlowDetailBloc>(
            create: (_) =>
                FlowDetailBloc(repo: _flowsRepo, id: id)
                  ..add(const FlowDetailLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Detalle de flujo')),
              body: const FlowDetailPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Listado de orgs del operador. Entry point único hoy: tile en
        // SettingsPage. Page-scoped: el bloc se construye y dispara
        // LoadRequested aquí; cuando aterrice cache RFC-0001, esta capa
        // sobrevive y la repo orquesta verdad local vs. remota.
        path: '/memberships',
        builder: (context, _) => BlocProvider<MembershipsBloc>(
          create: (_) =>
              MembershipsBloc(_membershipsRepo)
                ..add(const MembershipsLoadRequested()),
          child: Scaffold(
            appBar: AppBar(title: const Text('Tus organizaciones')),
            body: const MembershipsPage(),
          ),
        ),
      ),
      GoRoute(
        // Crear bot dentro del namespace de su Template padre. Forzar el
        // templateId como path param es la garantía estructural de que el
        // formulario (`BotCreatePage`) siempre nace ligado a una plantilla
        // concreta. La entrada sin plantilla previa vive en `/bots/new`,
        // que monta el selector y -- una vez elegida -- hace
        // pushReplacement a esta ruta. El templateName viaja como query
        // opcional para que el chip pueda mostrar el nombre real sin
        // reconsultar el backend; en su ausencia (deep-link directo a
        // la URL), el page exhibe un copy fallback.
        path: '/templates/:templateId/bots/new',
        builder: (context, state) {
          final templateId = state.pathParameters['templateId']!;
          final templateName = state.uri.queryParameters['name'];
          return BlocProvider<BotCreateBloc>(
            create: (_) => BotCreateBloc(repo: _botsRepo),
            child: Scaffold(
              appBar: AppBar(title: const Text('Crear bot')),
              body: BotCreatePage(
                templateId: templateId,
                templateName: templateName,
              ),
            ),
          );
        },
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = _authBloc.state;
    final location = state.matchedLocation;
    if (auth is AuthInitial) {
      // Hasta que el bloc decida, sólo dejamos pasar a `/` (Splash).
      // Cualquier intento de navegar directo a otra ruta antes del
      // primer check vuelve a / para evitar parpadeos.
      return location == '/' ? null : '/';
    }
    if (auth is AuthAuthenticated) {
      // Sesión válida: las rutas públicas redirigen a /home.
      return (location == '/' || location == '/login') ? '/home' : null;
    }
    // Unauthenticated: las rutas protegidas y el Splash van a /login.
    return location == '/login' ? null : '/login';
  }
}

/// Adapta el stream del bloc a un `Listenable` que GoRouter sabe
/// consumir. Cada emisión del bloc → `notifyListeners()` → re-evaluación
/// del `redirect`. Sin esto, el router sólo vería el estado al construirse.
class _AuthBlocListenable extends ChangeNotifier {
  _AuthBlocListenable(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
