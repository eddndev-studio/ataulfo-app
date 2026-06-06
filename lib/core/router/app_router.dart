import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_catalog/domain/repositories/catalog_repository.dart';
import '../../features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/accept_invitation_cubit.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/create_org_cubit.dart';
import '../../features/auth/presentation/bloc/forgot_password_bloc.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/bloc/register_bloc.dart';
import '../../features/auth/presentation/bloc/resend_verification_cubit.dart';
import '../../features/auth/presentation/bloc/rename_org_cubit.dart';
import '../../features/auth/presentation/bloc/reset_password_bloc.dart';
import '../../features/auth/presentation/bloc/switch_org_cubit.dart';
import '../../features/auth/presentation/bloc/verify_email_bloc.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/accept_invite_page.dart';
import '../../features/auth/presentation/pages/create_org_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/bots/domain/entities/bot.dart';
import '../../features/bots/domain/repositories/bot_session_repository.dart';
import '../../features/bots/domain/repositories/bots_repository.dart';
import '../../features/bots/presentation/bloc/bot_connect_bloc.dart';
import '../../features/bots/presentation/bloc/bot_create_bloc.dart';
import '../../features/bots/presentation/bloc/bot_detail_bloc.dart';
import '../../features/bots/presentation/bloc/bot_maintenance_bloc.dart';
import '../../features/bots/presentation/bloc/bot_variables_bloc.dart';
import '../../features/bots/presentation/bloc/bots_bloc.dart';
import '../../features/bots/presentation/pages/bot_connect_page.dart';
import '../../features/bots/presentation/pages/bot_create_page.dart';
import '../../features/bots/presentation/pages/bot_detail_page.dart';
import '../../features/bots/presentation/pages/bot_maintenance_page.dart';
import '../../features/bots/presentation/pages/bot_template_picker_page.dart';
import '../../features/bots/presentation/pages/bot_variables_page.dart';
import '../../features/conversations/domain/repositories/conversations_repository.dart';
import '../../features/conversations/presentation/bloc/conversations_bloc.dart';
import '../../features/conversations/presentation/pages/conversations_list_page.dart';
import '../../features/flows/domain/repositories/flows_repository.dart';
import '../../features/flows/presentation/bloc/flow_create_bloc.dart';
import '../../features/flows/presentation/bloc/flow_detail_bloc.dart';
import '../../features/flows/presentation/bloc/flow_steps_bloc.dart';
import '../../features/flows/presentation/bloc/flows_bloc.dart';
import '../../features/flows/presentation/bloc/media_names_cubit.dart';
import '../../features/flows/presentation/pages/flow_create_page.dart';
import '../../features/flows/presentation/pages/flow_detail_page.dart';
import '../../features/labels/domain/repositories/labels_repository.dart';
import '../../features/labels/presentation/bloc/labels_admin_bloc.dart';
import '../../features/media/domain/repositories/media_file_picker.dart';
import '../../features/media/domain/repositories/media_repository.dart';
import '../../features/invitations/domain/repositories/invitations_repository.dart';
import '../../features/invitations/presentation/bloc/invitation_mutation_cubit.dart';
import '../../features/invitations/presentation/bloc/invitations_bloc.dart';
import '../../features/invitations/presentation/pages/invitations_page.dart';
import '../../features/media/data/repositories/url_launcher_media_preview_launcher.dart';
import '../../features/media/domain/entities/media_asset.dart';
import '../../features/media/domain/repositories/media_thumbnail_loader.dart';
import '../../features/media/presentation/bloc/media_detail_cubit.dart';
import '../../features/media/presentation/bloc/media_gallery_bloc.dart';
import '../../features/media/presentation/pages/media_detail_page.dart';
import '../../features/media/presentation/pages/media_gallery_page.dart';
import '../../features/members/domain/repositories/members_repository.dart';
import '../../features/members/presentation/bloc/assign_bots_cubit.dart';
import '../../features/members/presentation/bloc/member_mutation_cubit.dart';
import '../../features/members/presentation/bloc/members_bloc.dart';
import '../../features/members/presentation/pages/bot_assignment_page.dart';
import '../../features/members/presentation/pages/members_page.dart';
import '../../features/memberships/domain/repositories/memberships_repository.dart';
import '../../features/memberships/presentation/bloc/memberships_bloc.dart';
import '../../features/memberships/presentation/pages/memberships_page.dart';
import '../../features/memberships/presentation/pages/select_org_page.dart';
import '../../features/messages/domain/repositories/messages_repository.dart';
import '../../features/messages/presentation/bloc/messages_bloc.dart';
import '../../features/messages/presentation/pages/message_thread_page.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/presentation/bloc/notification_preferences_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/notifications/presentation/pages/notification_preferences_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/widgets/chat_thread_app_bar.dart';
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
import '../../features/wa_labels/domain/repositories/wa_labels_repository.dart';
import '../../features/wa_labels/presentation/bloc/wa_label_mapping_bloc.dart';
import '../../features/wa_labels/presentation/bloc/wa_labels_bloc.dart';
import '../../features/wa_labels/presentation/pages/wa_label_mapping_page.dart';
import '../../features/wa_labels/presentation/pages/wa_labels_page.dart';
import '../auth/role_privilege.dart';

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
    required BotSessionRepository botSessionRepository,
    required ConversationsRepository conversationsRepository,
    required MessagesRepository messagesRepository,
    required ProfileRepository profileRepository,
    required TemplatesRepository templatesRepository,
    required FlowsRepository flowsRepository,
    required TriggersRepository triggersRepository,
    required WaLabelsRepository waLabelsRepository,
    required LabelsRepository labelsRepository,
    required MembershipsRepository membershipsRepository,
    required MembersRepository membersRepository,
    required InvitationsRepository invitationsRepository,
    required CatalogRepository catalogRepository,
    required NotificationsRepository notificationsRepository,
    required MediaRepository mediaRepository,
    required MediaFilePicker mediaFilePicker,
    required MediaThumbnailLoader mediaThumbnailLoader,
  }) : _authBloc = authBloc,
       _authRepo = authRepository,
       _botsRepo = botsRepository,
       _botSessionRepo = botSessionRepository,
       _conversationsRepo = conversationsRepository,
       _messagesRepo = messagesRepository,
       _profileRepo = profileRepository,
       _templatesRepo = templatesRepository,
       _flowsRepo = flowsRepository,
       _triggersRepo = triggersRepository,
       _waLabelsRepo = waLabelsRepository,
       _labelsRepo = labelsRepository,
       _membershipsRepo = membershipsRepository,
       _membersRepo = membersRepository,
       _invitationsRepo = invitationsRepository,
       _catalogRepo = catalogRepository,
       _notificationsRepo = notificationsRepository,
       _mediaRepo = mediaRepository,
       _mediaFilePicker = mediaFilePicker,
       _mediaThumbnailLoader = mediaThumbnailLoader;

  final AuthBloc _authBloc;
  final AuthRepository _authRepo;
  final BotsRepository _botsRepo;
  final BotSessionRepository _botSessionRepo;
  final ConversationsRepository _conversationsRepo;
  final MessagesRepository _messagesRepo;
  final ProfileRepository _profileRepo;
  final TemplatesRepository _templatesRepo;
  final FlowsRepository _flowsRepo;
  final TriggersRepository _triggersRepo;
  final WaLabelsRepository _waLabelsRepo;
  final LabelsRepository _labelsRepo;
  final MembershipsRepository _membershipsRepo;
  final MembersRepository _membersRepo;
  final InvitationsRepository _invitationsRepo;
  final CatalogRepository _catalogRepo;
  final NotificationsRepository _notificationsRepo;
  final MediaRepository _mediaRepo;
  final MediaFilePicker _mediaFilePicker;
  final MediaThumbnailLoader _mediaThumbnailLoader;

  /// Observer compartido entre el Navigator del GoRouter y los list pages
  /// del shell. El GoRouter notifica push/pop sobre este observer; las
  /// list pages (Bots, Templates) se suscriben en didChangeDependencies
  /// y dispatchan su refresh cuando una sub-ruta encima cierra. Sin esto
  /// el operador tiene que pull-to-refresh tras crear/editar.
  final RouteObserver<PageRoute<dynamic>> _routeObserver =
      RouteObserver<PageRoute<dynamic>>();

  /// Sub-rutas de configuración bot-level que el backend gatea ADMIN+
  /// (`/bots/:id/{variables,maintenance}`). El `_redirect` las desvía al
  /// detalle si el rol no alcanza.
  static final RegExp _adminOnlyBotRoute = RegExp(
    r'^/bots/[^/]+/(variables|maintenance)$',
  );

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthBlocListenable(_authBloc),
    redirect: _redirect,
    observers: <NavigatorObserver>[_routeObserver],
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const SplashPage()),
      GoRoute(
        // Selección de organización para el usuario multi-membership sin org
        // activa. Monta la lista de orgs (MembershipsBloc) y el switch
        // (SwitchOrgCubit) page-scoped; la página orquesta el flip de la
        // sesión tras un switch exitoso (el cubit no conoce el AuthBloc).
        path: '/select-org',
        builder: (context, _) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MembershipsBloc>(
              create: (_) =>
                  MembershipsBloc(_membershipsRepo)
                    ..add(const MembershipsLoadRequested()),
            ),
            BlocProvider<SwitchOrgCubit>(
              create: (_) => SwitchOrgCubit(_authRepo),
            ),
          ],
          child: Scaffold(
            appBar: AppBar(title: const Text('Selecciona una organización')),
            body: const SelectOrgPage(),
          ),
        ),
      ),
      GoRoute(
        // Crear organización. Alcanzable con sesión (incluida la NoOrg, vía el
        // allowlist del redirect: un sin-org debe poder crear su primera org).
        // La página persiste el par nuevo y rutea al shell tras el flip.
        path: '/create-org',
        builder: (context, _) => BlocProvider<CreateOrgCubit>(
          create: (_) => CreateOrgCubit(_authRepo),
          child: Scaffold(
            appBar: AppBar(title: const Text('Crear organización')),
            body: const CreateOrgPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => BlocProvider<LoginBloc>(
          create: (_) => LoginBloc(_authRepo),
          child: LoginPage(
            // El reset destructivo rebota aquí con `?reset=success` para que el
            // login avise que la contraseña ya cambió (la sesión fue revocada).
            justReset: state.uri.queryParameters['reset'] == 'success',
            onSucceeded: (_) {
              // El verify dispara la transición a Authenticated y el
              // redirect navega a /home. Los tokens los acaba de
              // persistir el AuthRepository.login(); el bloc los lee
              // a través de hasTokens() + me().
              _authBloc.add(const AuthCheckRequested());
            },
            // Empuja la pantalla de alta sobre el login; "Ya tengo cuenta"
            // hace pop para volver. El login se mantiene presentación pura
            // (sin import de go_router): la navegación la inyecta el router.
            onCreateAccount: () => context.push('/register'),
            // Empuja el flujo de recuperación; el back físico vuelve al login.
            onForgotPassword: () => context.push('/forgot-password'),
          ),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, _) => BlocProvider<RegisterBloc>(
          create: (_) => RegisterBloc(_authRepo),
          child: RegisterPage(
            onSucceeded: (_) {
              // El alta persiste el par de tokens (cuenta con su org personal
              // OWNER); AuthCheckRequested dispara Authenticated y el redirect
              // navega a /home, igual que el login.
              _authBloc.add(const AuthCheckRequested());
            },
            // Vuelve al login. Si la pantalla se empujó desde el login, basta
            // un pop; pero `/register` es ruta pública (deep-linkable), así que
            // un cold-open puede dejar la pila en un solo elemento — ahí pop
            // reventaría y se degrada a navegar al login.
            onGoToLogin: () =>
                context.canPop() ? context.pop() : context.go('/login'),
          ),
        ),
      ),
      GoRoute(
        // Solicitar el correo de reset. Ruta pública (deep-linkable). El correo
        // abre el SERVIDOR, no la app; "Ya tengo un código" empuja la pantalla
        // de reset para que el operador pegue ahí el enlace o el token.
        path: '/forgot-password',
        builder: (context, _) => BlocProvider<ForgotPasswordBloc>(
          create: (_) => ForgotPasswordBloc(_authRepo),
          child: ForgotPasswordPage(
            onHaveCode: () => context.push('/reset-password'),
          ),
        ),
      ),
      GoRoute(
        // Canjear el token de reset y fijar la nueva contraseña. Ruta pública
        // (deep-linkable). En 204 el backend revoca TODAS las familias de
        // refresh; la pantalla cierra la sesión local (AuthLoggedOut,
        // idempotente si no hay tokens) y rutea al login.
        path: '/reset-password',
        builder: (context, _) => BlocProvider<ResetPasswordBloc>(
          create: (_) => ResetPasswordBloc(_authRepo),
          child: ResetPasswordPage(
            onSucceeded: () {
              _authBloc.add(const AuthLoggedOut());
              context.go('/login?reset=success');
            },
          ),
        ),
      ),
      GoRoute(
        // Canjear el token de verificación de correo. Ruta pública
        // (deep-linkable) y permitida también con sesión: el operador puede
        // verificar logueado desde el aviso del shell. El correo abre el
        // SERVIDOR, no la app; el operador pega aquí el enlace o el token. Tras
        // el canje se refresca la sesión (AuthCheckRequested) para que el
        // `email_verified` de `/auth/me` se actualice y el aviso desaparezca, y
        // se vuelve atrás (pop si hay pila, si no a /home; el redirect corrige a
        // /login cuando no hay sesión).
        path: '/verify-email',
        builder: (context, _) => BlocProvider<VerifyEmailBloc>(
          create: (_) => VerifyEmailBloc(_authRepo),
          child: VerifyEmailPage(
            onSucceeded: ({required bool alreadyVerified}) {
              _authBloc.add(const AuthCheckRequested());
              context.canPop() ? context.pop() : context.go('/home');
            },
          ),
        ),
      ),
      GoRoute(
        // Canjear una invitación pendiente. Ruta pública (deep-linkable) y
        // permitida también con sesión: el canje exige estar logueado con el
        // correo invitado, así que la página se gobierna por el estado de la
        // sesión (sin sesión dirige a autenticarse; con sesión muestra el
        // formulario). Page-scoped: `AcceptInvitationCubit` se construye con el
        // repo. La página no recibe callbacks de navegación — navega ella misma
        // según el estado de la sesión (a /login o /register sin sesión; a la
        // superficie de switch tras aceptar para activar la org nueva).
        path: '/accept-invite',
        builder: (context, _) => BlocProvider<AcceptInvitationCubit>(
          create: (_) => AcceptInvitationCubit(_authRepo),
          child: Scaffold(
            appBar: AppBar(title: const Text('Aceptar invitación')),
            body: const AcceptInvitePage(),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, _) {
          // El subárbol del shell se keyea por el orgId activo: al cambiar de
          // org (switch-org), el KeyedSubtree destruye y recrea el
          // MultiBlocProvider y sus blocs page-scoped, que recargan datos de la
          // org nueva — sin esto, un switch dejaría las listas (bots,
          // plantillas, etiquetas) de la org vieja vivas debajo. Se keyea por
          // orgId SOLO, no por la identity completa: un refresh de /auth/me que
          // sólo confirme el correo conserva el orgId, y el aviso de
          // verificación debe actualizarse sin nukear las listas.
          final auth = context.watch<AuthBloc>().state;
          final orgId = auth is AuthAuthenticated ? auth.identity.orgId : '';
          return KeyedSubtree(
            key: ValueKey<String>(orgId),
            child: MultiBlocProvider(
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
                BlocProvider<LabelsAdminBloc>(
                  create: (_) =>
                      LabelsAdminBloc(repo: _labelsRepo)
                        ..add(const LabelsAdminLoadRequested()),
                ),
                // Cubit del reenvío de verificación, scoped al shell para que el
                // aviso "verifica tu correo" lo dispare y reaccione a su
                // SnackBar.
                BlocProvider<ResendVerificationCubit>(
                  create: (_) => ResendVerificationCubit(_authRepo),
                ),
              ],
              // Blocs page-scoped a nivel del shell: cambiar de tab no
              // rebuildea los providers y cada lista preserva estado
              // (Loaded, refresh, failures) entre Bots ⇄ Plantillas ⇄ Ajustes.
              // El routeObserver se atraviesa al shell para que ambos list
              // pages disparen su refresh al volver de una sub-ruta.
              child: ShellPage(routeObserver: _routeObserver),
            ),
          );
        },
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
          // El `TemplatesRepository` cuelga del scope para el toggle de IA
          // (lee `Template.ai.enabled` para la IA efectiva). Sólo el render
          // ADMIN+ lo consume; la carga compartida no fetchea la Template,
          // así un WORKER (ruta WORKER+) nunca cruza ese endpoint ADMIN+.
          return RepositoryProvider<TemplatesRepository>.value(
            value: _templatesRepo,
            child: BlocProvider<BotDetailBloc>(
              create: (_) =>
                  BotDetailBloc(repo: _botsRepo, id: id)
                    ..add(const BotDetailLoadRequested()),
              child: Scaffold(
                appBar: AppBar(title: const Text('Detalle del bot')),
                body: const BotDetailPage(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        // Compartir enlace de conexión (S04 RF#7): arranca la sesión del bot
        // y emite el ConnectLink a compartir. Sub-ruta de `/bots/:id` con un
        // segmento más, así no compite con el detalle por orden de match.
        // Page-scoped: el `BotConnectBloc` se construye con el ID y dispara
        // Started al montarse.
        path: '/bots/:id/connect',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // El `?channel=` (lo pasa el detalle) gatea la sección de wipe; ausente
          // o desconocido ⇒ WA_UNOFFICIAL (el único canal hoy; deep-link safe).
          final channel = state.uri.queryParameters['channel'] == 'WABA'
              ? BotChannel.waba
              : BotChannel.waUnofficial;
          return BlocProvider<BotConnectBloc>(
            create: (_) =>
                BotConnectBloc(repo: _botSessionRepo, botId: id)
                  ..add(const BotConnectStarted()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Conectar WhatsApp')),
              body: BotConnectPage(channel: channel),
            ),
          );
        },
      ),
      GoRoute(
        // Editor de variable_values del bot (S04). Sub-ruta de `/bots/:id`.
        // Page-scoped y cross-feature: `BotVariablesBloc` obtiene el bot él
        // mismo (byId → version+templateId) y las defs del template para sembrar
        // el form; el PUT envía la versión del BOT (MAJOR 2). El gateo ADMIN+ de
        // esta ruta vive en `_redirect` (un WORKER deep-link cae al detalle).
        path: '/bots/:id/variables',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<BotVariablesBloc>(
            create: (_) => BotVariablesBloc(
              botsRepo: _botsRepo,
              templatesRepo: _templatesRepo,
              botId: id,
            )..add(const BotVariablesLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Variables del bot')),
              body: const BotVariablesPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Zona Peligrosa Tier A (S04): clear-conversations / reset-sessions, que
        // exigen paused. Sub-ruta de `/bots/:id`; gateada ADMIN+ en `_redirect`
        // (WORKER deep-link cae al detalle). Cross-feature: Bots (paused/toggle)
        // + BotSession (clear/reset).
        path: '/bots/:id/maintenance',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<BotMaintenanceBloc>(
            create: (_) => BotMaintenanceBloc(
              botsRepo: _botsRepo,
              sessionRepo: _botSessionRepo,
              botId: id,
            )..add(const BotMaintenanceLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Mantenimiento')),
              body: const BotMaintenancePage(),
            ),
          );
        },
      ),
      GoRoute(
        // Catálogo de etiquetas WhatsApp del bot (S21). Sub-ruta de `/bots/:id`
        // con un segmento más, así no compite con el detalle por orden de match.
        // Page-scoped: `WaLabelsBloc` se construye con el botId, dispara el
        // primer load y se suscribe al realtime `label.wa.*` al montarse.
        path: '/bots/:id/wa-labels',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<WaLabelsBloc>(
            create: (_) =>
                WaLabelsBloc(repo: _waLabelsRepo, botId: id)
                  ..add(const WaLabelsLoadRequested()),
            // La página posee su Scaffold (AppBar + FAB de crear + sheets).
            child: const WaLabelsPage(),
          );
        },
      ),
      GoRoute(
        // Mapeo etiqueta-WhatsApp ↔ Label interno (S21 Dirección 2). Segmento
        // distinto de `wa-labels` ⇒ no compite por orden de match. Page-scoped:
        // `WaLabelMappingBloc` une catálogo + mapeos + labels internos al montar.
        path: '/bots/:id/wa-label-mappings',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<WaLabelMappingBloc>(
            create: (_) => WaLabelMappingBloc(
              waRepo: _waLabelsRepo,
              labelsRepo: _labelsRepo,
              botId: id,
            )..add(const WaMappingLoadRequested()),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Vínculos con etiquetas internas'),
              ),
              body: const WaLabelMappingPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Conversaciones (sesiones S07 RF#7) del bot: bandeja per-bot. Sub-ruta
        // de `/bots/:id` con un segmento más, así no compite con el detalle por
        // orden de match. Page-scoped: `ConversationsBloc` se construye con el
        // ID y dispara el primer load al montarse.
        path: '/bots/:id/sessions',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // El repo de etiquetas WA cuelga del scope para el sheet de etiquetas
          // por chat (la fila de la bandeja lo abre con su chatLid + kind).
          return RepositoryProvider<WaLabelsRepository>.value(
            value: _waLabelsRepo,
            child: BlocProvider<ConversationsBloc>(
              create: (_) =>
                  ConversationsBloc(repo: _conversationsRepo, botId: id)
                    ..add(const ConversationsLoadRequested()),
              child: Scaffold(
                appBar: AppBar(title: const Text('Conversaciones')),
                body: const ConversationsListPage(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        // Hilo de mensajes de una conversación (S09 RF#5). Sub-ruta de
        // `/bots/:id/sessions` con el chatLid como segmento extra; declarada
        // después para no competir con la bandeja por orden de match. El
        // chatLid llega DECODIFICADO de go_router (los grupos llevan `@`); el
        // datasource lo re-encodea para el wire. Page-scoped: `MessagesBloc`
        // se construye con botId+chatLid y dispara el primer load (la cola).
        path: '/bots/:id/sessions/:chatLid',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final chatLid = state.pathParameters['chatLid']!;
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<MessagesBloc>(
                create: (_) => MessagesBloc(
                  repo: _messagesRepo,
                  botId: id,
                  chatLid: chatLid,
                )..add(const MessagesLoadRequested()),
              ),
              // El perfil alimenta el header (avatar + nombre real) y se
              // re-monta en la pantalla de perfil; dos cargas hoy, la cache
              // RFC-0001 las absorberá.
              BlocProvider<ProfileBloc>(
                create: (_) =>
                    ProfileBloc(repo: _profileRepo, botId: id, chatLid: chatLid)
                      ..add(const ProfileLoadRequested()),
              ),
            ],
            child: Scaffold(
              appBar: ChatThreadAppBar(botId: id, chatLid: chatLid),
              body: const MessageThreadPage(),
            ),
          );
        },
      ),
      GoRoute(
        // "Revisar perfil" de una conversación. Sub-ruta del hilo con un
        // segmento `/profile` extra (5 segmentos vs. 4 del hilo) ⇒ no compite
        // por orden de match. Page-scoped: `ProfileBloc` se construye con
        // botId+chatLid y dispara el load al montarse.
        path: '/bots/:id/sessions/:chatLid/profile',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final chatLid = state.pathParameters['chatLid']!;
          return BlocProvider<ProfileBloc>(
            create: (_) =>
                ProfileBloc(repo: _profileRepo, botId: id, chatLid: chatLid)
                  ..add(const ProfileLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Perfil')),
              body: const ProfilePage(),
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
        // Crear flow desde el TemplateDetailPage (S11 F4). Subruta del
        // template (`/templates/:templateId/flows/new`) — no compite
        // con `/templates/:id` por orden de match. Page-scoped:
        // `FlowCreateBloc` se construye con el templateId; Succeeded
        // hace `pushReplacement('/flows/:id')` para sacar el form de
        // la pila (back físico vuelve al detalle de plantilla).
        path: '/templates/:templateId/flows/new',
        builder: (context, state) {
          final templateId = state.pathParameters['templateId']!;
          return BlocProvider<FlowCreateBloc>(
            create: (_) =>
                FlowCreateBloc(repo: _flowsRepo, templateId: templateId),
            child: Scaffold(
              appBar: AppBar(title: const Text('Crear flujo')),
              body: const FlowCreatePage(),
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
          // El tab de Disparadores consume `TriggersRepository` (CRUD de
          // triggers) y `LabelsRepository` (catálogo que alimenta el
          // selector de etiqueta del trigger LABEL). Ambos cuelgan del
          // scope de la página para que el `_openSheet` los lleve al
          // subtree del sheet.
          return MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<TriggersRepository>.value(
                value: _triggersRepo,
              ),
              RepositoryProvider<LabelsRepository>.value(value: _labelsRepo),
            ],
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<FlowDetailBloc>(
                  create: (_) =>
                      FlowDetailBloc(repo: _flowsRepo, id: id)
                        ..add(const FlowDetailLoadRequested()),
                ),
                BlocProvider<FlowStepsBloc>(
                  create: (_) =>
                      FlowStepsBloc(repo: _flowsRepo, flowId: id)
                        ..add(const FlowStepsLoadRequested()),
                ),
                // Resuelve el ref BARE de cada paso multimedia al nombre/alias
                // EN VIVO del catálogo, para que la lista muestre el nombre
                // legible en vez del id. Carga al abrir el flujo.
                BlocProvider<MediaNamesCubit>(
                  create: (_) => MediaNamesCubit(repo: _mediaRepo)..load(),
                ),
              ],
              child: Scaffold(
                appBar: AppBar(title: const Text('Detalle de flujo')),
                body: const FlowDetailPage(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        // Listado de orgs del operador con cambio de organización in-app. Entry
        // point único hoy: tile en SettingsPage. Page-scoped: el
        // MembershipsBloc dispara LoadRequested al construirse y el
        // SwitchOrgCubit habilita el switch (la página orquesta el flip de la
        // sesión y la navegación al shell, ya re-keyeado, tras un switch
        // exitoso; el cubit no conoce el AuthBloc).
        path: '/memberships',
        builder: (context, _) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MembershipsBloc>(
              create: (_) =>
                  MembershipsBloc(_membershipsRepo)
                    ..add(const MembershipsLoadRequested()),
            ),
            BlocProvider<SwitchOrgCubit>(
              create: (_) => SwitchOrgCubit(_authRepo),
            ),
            BlocProvider<RenameOrgCubit>(
              create: (_) => RenameOrgCubit(_authRepo),
            ),
          ],
          child: Scaffold(
            appBar: AppBar(title: const Text('Tus organizaciones')),
            body: const MembershipsPage(),
          ),
        ),
      ),
      GoRoute(
        // Roster de la org activa. Entry point: tile admin-gated en SettingsPage
        // (el gate es cosmético; el backend 403ea a roles por debajo de ADMIN).
        // Page-scoped: el MembersBloc dispara LoadRequested al construirse y el
        // MemberMutationCubit habilita cambiar rol / quitar (la página cierra el
        // lazo recargando tras una mutación exitosa; el cubit no conoce el bloc).
        path: '/members',
        builder: (context, _) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MembersBloc>(
              create: (_) =>
                  MembersBloc(_membersRepo)..add(const MembersLoadRequested()),
            ),
            BlocProvider<MemberMutationCubit>(
              create: (_) => MemberMutationCubit(_membersRepo),
            ),
          ],
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Miembros'),
              actions: <Widget>[
                IconButton(
                  key: const Key('members.invite'),
                  tooltip: 'Invitar',
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () => context.push('/invitations'),
                ),
              ],
            ),
            body: const MembersPage(),
          ),
        ),
      ),
      GoRoute(
        // Asignación de bots a un miembro WORKER. Se apila desde MemberEditSheet
        // ("Asignar bots"). El AssignBotsCubit cruza dos features (bots de la org
        // + asignación del miembro) y dispara la carga al construirse.
        path: '/members/:id/bots',
        builder: (context, state) => BlocProvider<AssignBotsCubit>(
          create: (_) => AssignBotsCubit(
            membershipId: state.pathParameters['id']!,
            membersRepo: _membersRepo,
            botsRepo: _botsRepo,
          )..load(),
          child: Scaffold(
            appBar: AppBar(title: const Text('Asignar bots')),
            body: const BotAssignmentPage(),
          ),
        ),
      ),
      GoRoute(
        // Historial de invitaciones de la org + emitir / cancelar. Entry point:
        // acción "Invitar" en la AppBar de /members. Page-scoped: el
        // InvitationsBloc dispara LoadRequested al construirse y el
        // InvitationMutationCubit habilita crear/cancelar (la página cierra el
        // lazo recargando tras una mutación; el cubit no conoce el bloc).
        path: '/invitations',
        builder: (context, _) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<InvitationsBloc>(
              create: (_) =>
                  InvitationsBloc(_invitationsRepo)
                    ..add(const InvitationsLoadRequested()),
            ),
            BlocProvider<InvitationMutationCubit>(
              create: (_) => InvitationMutationCubit(_invitationsRepo),
            ),
          ],
          child: Scaffold(
            appBar: AppBar(title: const Text('Invitaciones')),
            body: const InvitationsPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, _) => BlocProvider<NotificationsBloc>(
          create: (_) =>
              NotificationsBloc(_notificationsRepo)
                ..add(const NotificationsLoadRequested()),
          child: Scaffold(
            appBar: AppBar(title: const Text('Notificaciones')),
            body: const NotificationsPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/notification-preferences',
        builder: (context, _) => BlocProvider<NotificationPreferencesBloc>(
          create: (_) =>
              NotificationPreferencesBloc(_notificationsRepo)
                ..add(const NotificationPreferencesLoadRequested()),
          child: Scaffold(
            appBar: AppBar(title: const Text('Preferencias')),
            body: const NotificationPreferencesPage(),
          ),
        ),
      ),
      GoRoute(
        // Galería de media de la org. Entry point: tile en SettingsPage.
        // Reusable como picker abriéndola con un `onSelect` que devuelve el
        // `ref` BARE. Page-scoped: el bloc se construye con repo + picker y
        // dispara el primer load al montarse.
        path: '/media',
        builder: (context, _) => BlocProvider<MediaGalleryBloc>(
          create: (_) =>
              MediaGalleryBloc(repo: _mediaRepo, picker: _mediaFilePicker)
                ..add(const MediaGalleryLoadRequested()),
          child: Scaffold(
            appBar: AppBar(title: const Text('Galería de multimedia')),
            // En modo browse, tocar un asset abre su detalle; si el detalle
            // reporta un cambio (borrado/renombrado) al hacer pop, la página se
            // refresca. El picker usa onSelect (pop con el ref); aquí onOpenDetail.
            body: MediaGalleryPage(
              loader: _mediaThumbnailLoader,
              showTypeTabs: true,
              onOpenDetail: (asset) async =>
                  (await context.push<bool>('/media/detail', extra: asset)) ??
                  false,
            ),
          ),
        ),
      ),
      GoRoute(
        // Detalle de un asset: previsualización + metadata + copiar ref + borrar.
        // Se alcanza por push con el MediaAsset en `extra`; un acceso sin extra
        // (deep-link directo) cae a un estado vacío en vez de crashear. El
        // MediaDetailCubit (con el repo) gobierna las mutaciones del detalle.
        path: '/media/detail',
        builder: (context, state) {
          final asset = state.extra;
          if (asset is! MediaAsset) {
            return const Scaffold(
              body: Center(child: Text('Archivo no disponible')),
            );
          }
          return BlocProvider<MediaDetailCubit>(
            create: (_) => MediaDetailCubit(repo: _mediaRepo, asset: asset),
            child: MediaDetailPage(
              loader: _mediaThumbnailLoader,
              launcher: const UrlLauncherMediaPreviewLauncher(),
            ),
          );
        },
      ),
      GoRoute(
        // La misma galería en modo selección: un `push` a esta ruta abre el
        // grid como picker; tocar un asset hace pop devolviendo su `ref` BARE
        // al caller que espera el resultado. La `previewUrl` firmada NUNCA
        // sale por aquí — sólo el ref canónico que se persiste en el step.
        // Segmento extra bajo `/media` (no compite por orden de match al no
        // existir un `/media/:id`).
        path: '/media/pick',
        builder: (context, state) {
          // `?type=` filtra la galería-picker por familia (image|video|audio|
          // document) según el tipo del paso de flujo que la abrió; ausente ⇒
          // galería completa. El asset elegido vuelve por `pop` ENTERO (ref +
          // content_type + filename); el caller persiste sólo el ref BARE.
          final type = state.uri.queryParameters['type'];
          return BlocProvider<MediaGalleryBloc>(
            create: (_) => MediaGalleryBloc(
              repo: _mediaRepo,
              picker: _mediaFilePicker,
              type: type,
            )..add(const MediaGalleryLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Elegir multimedia')),
              body: MediaGalleryPage(
                onSelect: (asset) => context.pop(asset),
                loader: _mediaThumbnailLoader,
              ),
            ),
          );
        },
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

  String? _redirect(BuildContext context, GoRouterState state) =>
      redirectForState(_authBloc.state, state.matchedLocation);
}

/// Rutas alcanzables SIN sesión: los flujos de entrada del arco de auth. El
/// `_redirect` las deja pasar estando `Unauthenticated` (en vez de mandar todo
/// a `/login`) y las preserva en `AuthInitial` (un cold-open de deep-link
/// `reset`/`accept` conserva su `?token=` en lugar de descartarse a `/`).
const Set<String> _publicRoutes = <String>{
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/accept-invite',
  '/verify-email',
};

/// `true` si [loc] es una ruta pública. Match por prefijo: el path base o
/// cualquier sub-path/query (`/reset-password?token=…`) cuenta como público.
bool _isPublic(String loc) => _publicRoutes.any(
  (p) => loc == p || loc.startsWith('$p/') || loc.startsWith('$p?'),
);

/// Decisión de redirect en función del estado de auth y la ubicación. Pura y
/// `static`-equivalente (top-level) para testearse sin construir el GoRouter:
/// el `_redirect` del router sólo le pasa el estado del bloc y la
/// `matchedLocation`.
@visibleForTesting
String? redirectForState(AuthState auth, String location) {
  switch (auth) {
    case AuthInitial():
      // Antes del primer check sólo conocemos el destino crudo. Una ruta
      // pública (incluida su query con token) se preserva; cualquier otra
      // vuelve a `/` (Splash) para evitar parpadeos hasta que el bloc decida.
      if (_isPublic(location)) return null;
      return location == '/' ? null : '/';
    case AuthUnauthenticated():
      // Sin sesión, sólo las rutas públicas son alcanzables; el resto va a
      // /login.
      return _isPublic(location) ? null : '/login';
    case AuthAuthenticated(:final identity):
      // Gateo ADMIN+ de las sub-rutas de configuración bot-level (el backend
      // las cabla adminOnly y 403ea a WORKER). Un deep-link de WORKER cae al
      // detalle del bot en vez de pintar una pantalla que fallaría. Es gateo
      // cosmético: la autoridad real sigue siendo el 403/404 del backend.
      if (AppRouter._adminOnlyBotRoute.hasMatch(location) &&
          !isAdminOrAbove(identity.role)) {
        return location.substring(0, location.lastIndexOf('/'));
      }
      // Sesión válida: las rutas de entrada rebotan a /home; verify/accept se
      // permiten (el operador puede verificar o aceptar invitaciones logueado).
      // `/select-org` también rebota: un switch que flipa NoOrg→Authenticated
      // deja la ubicación en la selección, y un usuario con org activa nunca
      // debe quedarse varado ahí.
      if (location == '/' ||
          location == '/login' ||
          location == '/register' ||
          location == '/select-org') {
        return '/home';
      }
      return null;
    case AuthAuthenticatedNoOrg():
      // Sin org activa, todo se desvía a la selección de organización salvo la
      // propia selección, verify/accept y crear-org (que se permiten para no
      // encerrar al operador: un sin-org debe poder crear su primera org).
      if (location == '/select-org' ||
          location == '/verify-email' ||
          location == '/accept-invite' ||
          location == '/create-org') {
        return null;
      }
      return '/select-org';
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
