import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_catalog/domain/repositories/catalog_repository.dart';
import '../../features/ai_catalog/presentation/bloc/catalog_bloc.dart';
import '../../features/billing/data/repositories/url_launcher_web_link_launcher.dart';
import '../../features/billing/domain/repositories/billing_repository.dart';
import '../../features/billing/presentation/bloc/entitlement_bloc.dart';
import '../../features/billing/presentation/pages/cuenta_page.dart';
import '../../features/calendar/domain/repositories/calendar_repository.dart';
import '../../features/calendar/presentation/bloc/agenda_cubit.dart';
import '../../features/calendar/presentation/bloc/booking_cubit.dart';
import '../../features/calendar/presentation/bloc/business_hours_cubit.dart';
import '../../features/calendar/presentation/bloc/event_types_cubit.dart';
import '../../features/calendar/presentation/pages/booking_page.dart';
import '../../features/calendar/presentation/pages/business_hours_page.dart';
import '../../features/calendar/presentation/pages/event_types_page.dart';
import '../../features/calendar/presentation/widgets/chat_appointment_badge.dart';
import '../../features/product_catalog/domain/repositories/composition_repository.dart';
import '../../features/product_catalog/domain/repositories/product_catalog_repository.dart';
import '../../features/product_catalog/presentation/bloc/product_catalog_cubit.dart';
import '../../features/product_catalog/presentation/pages/product_catalog_page.dart';
import '../../features/product_catalog/presentation/product_thumb_resolver.dart';
import '../../features/product_catalog/presentation/widgets/compose_photo_sheet.dart';
import '../../features/product_catalog/presentation/widgets/product_catalog_fab.dart';
import '../../features/org_ai_config/domain/repositories/org_ai_config_repository.dart';
import '../../features/org_ai_config/presentation/bloc/org_ai_config_bloc.dart';
import '../../features/org_ai_config/presentation/pages/org_ai_config_page.dart';
import '../../features/org_customization/domain/repositories/org_branding_repository.dart';
import '../../features/org_customization/presentation/bloc/org_customization_cubit.dart';
import '../../features/org_customization/presentation/pages/org_customization_page.dart';
import '../../features/public_catalog/domain/repositories/public_catalog_repository.dart';
import '../../features/public_catalog/presentation/bloc/public_catalog_cubit.dart';
import '../../features/public_catalog/presentation/pages/public_catalog_page.dart';
import '../../features/stickers/domain/repositories/sticker_repository.dart';
import '../../features/stickers/presentation/bloc/sticker_cubit.dart';
import '../../features/stickers/presentation/pages/sticker_picker_page.dart';
import '../../features/stickers/presentation/pages/stickers_page.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/accept_invitation_cubit.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/create_org_cubit.dart';
import '../../features/auth/presentation/bloc/forgot_password_bloc.dart';
import '../../features/auth/presentation/bloc/login_bloc.dart';
import '../../features/auth/presentation/bloc/pending_invitations_cubit.dart';
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
import '../../features/bots/presentation/bloc/bot_detail_bloc.dart';
import '../../features/bots/presentation/bloc/bot_maintenance_bloc.dart';
import '../../features/bots/presentation/bloc/bot_session_status_bloc.dart';
import '../../features/bots/presentation/bloc/bot_sessions_cubit.dart';
import '../../features/bots/presentation/bloc/bot_variables_bloc.dart';
import '../../features/bots/presentation/bloc/bots_bloc.dart';
import '../../features/bots/presentation/bot_create_draft.dart';
import '../../features/bots/presentation/pages/bot_connect_page.dart';
import '../../features/bots/presentation/pages/bot_detail_page.dart';
import '../../features/bots/presentation/pages/bot_maintenance_page.dart';
import '../../features/bots/presentation/pages/bot_variables_page.dart';
import '../../features/conversations/domain/repositories/conversations_repository.dart';
import '../../features/conversations/presentation/bloc/conversations_bloc.dart';
import '../../features/conversations/presentation/cubit/inbox_labels_cubit.dart';
import '../../features/conversations/presentation/pages/conversations_list_page.dart';
import '../../features/flow_run/domain/repositories/flow_run_repository.dart';
import '../../features/flows/domain/repositories/flows_repository.dart';
import '../../features/flows/presentation/bloc/flow_detail_bloc.dart';
import '../../features/flows/presentation/bloc/flow_steps_bloc.dart';
import '../../features/flows/presentation/bloc/flows_bloc.dart';
import '../../features/flows/presentation/bloc/media_names_cubit.dart';
import '../../features/flows/presentation/pages/flow_detail_page.dart';
import '../../features/flows/presentation/pages/flow_settings_page.dart';
import '../../features/flows/presentation/widgets/flow_detail_app_bar.dart';
import '../../features/labels/domain/repositories/chat_labels_repository.dart';
import '../../features/labels/domain/repositories/labels_repository.dart';
import '../../features/trainer/domain/repositories/trainer_repositories.dart';
import '../../features/trainer/presentation/bloc/preview_bloc.dart';
import '../../features/trainer/presentation/pages/preview_page.dart';
import '../../features/resources/domain/repositories/resources_repository.dart';
import '../../features/resources/presentation/bloc/assistant_resources_cubit.dart';
import '../../features/resources/presentation/pages/assistant_resources_page.dart';
import '../../features/platform_agent/domain/repositories/platform_agent_repository.dart';
import '../../features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import '../../features/ai_ledger/domain/ai_ledger_repository.dart';
import '../../features/ai_ledger/presentation/bloc/ai_ledger_bloc.dart';
import '../../features/ai_ledger/presentation/pages/ai_ledger_page.dart';
import '../../features/ai_log/domain/ai_log_repository.dart';
import '../../features/ai_log/presentation/bloc/ai_log_bloc.dart';
import '../../features/ai_log/presentation/pages/ai_log_page.dart';
import '../../features/executions/domain/execution_repository.dart';
import '../../features/executions/presentation/cubit/executions_cubit.dart';
import '../../features/executions/presentation/pages/executions_page.dart';
import '../../features/notes/domain/repositories/notes_repository.dart';
import '../../features/labels/presentation/bloc/labels_admin_bloc.dart';
import '../../features/labels/presentation/bloc/labels_bloc.dart';
import '../../features/media/domain/repositories/camera_capture.dart';
import '../../features/media/domain/repositories/device_gallery_port.dart';
import '../../features/media/domain/repositories/media_file_picker.dart';
import '../../features/media/data/repositories/file_picker_media_file_picker.dart';
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
import '../../features/messages/domain/repositories/audio_engine.dart';
import '../audio/audio_recorder.dart';
import '../../features/messages/data/cache/message_media_cache.dart';
import '../../features/messages/domain/repositories/media_opener.dart';
import '../../features/messages/domain/repositories/media_sharer.dart';
import '../../features/messages/presentation/widgets/video_playback.dart';
import '../../features/messages/domain/repositories/messages_repository.dart';
import '../../features/messages/presentation/bloc/messages_bloc.dart';
import '../../features/messages/presentation/bloc/thread_audio_cubit.dart';
import '../../features/messages/presentation/pages/message_thread_page.dart';
import '../../features/monitor/data/datasources/monitor_activity_datasource.dart';
import '../../features/monitor/data/datasources/monitor_catchup_datasource.dart';
import '../../features/monitor/presentation/cubit/monitor_attention_cubit.dart';
import '../../features/monitor/presentation/cubit/monitor_live_cubit.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/presentation/bloc/notification_preferences_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/notifications/presentation/pages/notification_preferences_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../../features/settings/presentation/pages/appearance_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/widgets/chat_thread_app_bar.dart';
import '../../features/quick_replies/domain/repositories/quick_replies_repository.dart';
import '../../features/quick_replies/presentation/bloc/quick_replies_bloc.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/splash/presentation/pages/reconnecting_view.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/templates/domain/repositories/templates_repository.dart';
import '../../features/templates/presentation/bloc/template_detail_bloc.dart';
import '../../features/templates/presentation/bloc/templates_bloc.dart';
import '../../features/templates/presentation/bloc/var_defs_bloc.dart';
import '../../features/templates/presentation/pages/template_ai_page.dart';
import '../../features/templates/presentation/pages/assistant_channels_page.dart';
import '../../features/templates/presentation/pages/template_detail_page.dart';
import '../../features/templates/presentation/pages/template_flows_page.dart';
import '../../features/templates/presentation/pages/template_variables_page.dart';
import '../../features/triggers/domain/repositories/triggers_repository.dart';
import '../../features/triggers/presentation/bloc/triggers_bloc.dart';
import '../../features/triggers/presentation/pages/flow_triggers_page.dart';
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
    required FlowRunRepository flowRunRepository,
    required TriggersRepository triggersRepository,
    required WaLabelsRepository waLabelsRepository,
    required QuickRepliesRepository quickRepliesRepository,
    required LabelsRepository labelsRepository,
    required ChatLabelsRepository chatLabelsRepository,
    required NotesRepository notesRepository,
    required AiLogRepository aiLogRepository,
    AiLedgerRepository? aiLedgerRepository,
    required ExecutionRepository executionsRepository,
    required TrainerRepository trainerRepository,
    required TrainerEvents trainerEvents,
    required MonitorActivityDatasource monitorActivity,
    required MonitorBotActivityDatasource monitorBotActivity,
    MonitorCatchupDatasource? monitorCatchup,
    required WorkspaceRepository workspaceRepository,
    required PreviewRepository previewRepository,
    ResourcesRepository? resourcesRepository,
    required PlatformAgentRepository platformAgentRepository,
    required PlatformAgentEvents platformAgentEvents,
    required MembershipsRepository membershipsRepository,
    required MembersRepository membersRepository,
    required InvitationsRepository invitationsRepository,
    required CatalogRepository catalogRepository,
    required CalendarRepository calendarRepository,
    ProductCatalogRepository? productCatalogRepository,
    CompositionRepository? compositionRepository,
    BillingRepository? billingRepository,
    String webBaseUrl = 'https://ataulfo.app',
    required OrgAiConfigRepository orgAiConfigRepository,
    OrgBrandingRepository? orgBrandingRepository,
    PublicCatalogRepository? publicCatalogRepository,
    StickerRepository? stickerRepository,
    required NotificationsRepository notificationsRepository,
    required MediaRepository mediaRepository,
    required MediaFilePicker mediaFilePicker,
    required CameraCapture cameraCapture,
    required DeviceGalleryPort deviceGallery,
    required MediaThumbnailLoader mediaThumbnailLoader,
    required MediaOpener mediaOpener,
    required MediaSharer mediaSharer,
    required AudioEngine Function() audioEngineFactory,
    required AudioRecorder audioRecorder,
  }) : _authBloc = authBloc,
       _authRepo = authRepository,
       _botsRepo = botsRepository,
       _botSessionRepo = botSessionRepository,
       _conversationsRepo = conversationsRepository,
       _messagesRepo = messagesRepository,
       _profileRepo = profileRepository,
       _templatesRepo = templatesRepository,
       _flowsRepo = flowsRepository,
       _flowRunRepo = flowRunRepository,
       _triggersRepo = triggersRepository,
       _waLabelsRepo = waLabelsRepository,
       _quickRepliesRepo = quickRepliesRepository,
       _labelsRepo = labelsRepository,
       _chatLabelsRepo = chatLabelsRepository,
       _notesRepo = notesRepository,
       _aiLogRepo = aiLogRepository,
       _aiLedgerRepo = aiLedgerRepository,
       _executionsRepo = executionsRepository,
       _monitorActivity = monitorActivity,
       _monitorBotActivity = monitorBotActivity,
       _monitorCatchup = monitorCatchup,
       _previewRepo = previewRepository,
       _resourcesRepo = resourcesRepository,
       _platformAgentRepo = platformAgentRepository,
       _platformAgentEvents = platformAgentEvents,
       _membershipsRepo = membershipsRepository,
       _membersRepo = membersRepository,
       _invitationsRepo = invitationsRepository,
       _catalogRepo = catalogRepository,
       _calendarRepo = calendarRepository,
       _productCatalogRepo = productCatalogRepository,
       _compositionRepo = compositionRepository,
       _billingRepo = billingRepository,
       _webBaseUrl = webBaseUrl,
       _orgAiConfigRepo = orgAiConfigRepository,
       _orgBrandingRepo = orgBrandingRepository,
       _publicCatalogRepo = publicCatalogRepository,
       _stickerRepo = stickerRepository,
       _notificationsRepo = notificationsRepository,
       _mediaRepo = mediaRepository,
       _mediaFilePicker = mediaFilePicker,
       _cameraCapture = cameraCapture,
       _deviceGallery = deviceGallery,
       _mediaThumbnailLoader = mediaThumbnailLoader,
       _mediaOpener = mediaOpener,
       _mediaSharer = mediaSharer,
       _audioEngineFactory = audioEngineFactory,
       _audioRecorder = audioRecorder;

  final AuthBloc _authBloc;
  final AuthRepository _authRepo;
  final BotsRepository _botsRepo;
  final BotSessionRepository _botSessionRepo;
  final ConversationsRepository _conversationsRepo;
  final MessagesRepository _messagesRepo;
  final ProfileRepository _profileRepo;
  final TemplatesRepository _templatesRepo;
  final FlowsRepository _flowsRepo;
  final FlowRunRepository _flowRunRepo;
  final TriggersRepository _triggersRepo;
  final WaLabelsRepository _waLabelsRepo;
  final QuickRepliesRepository _quickRepliesRepo;
  final LabelsRepository _labelsRepo;
  final ChatLabelsRepository _chatLabelsRepo;
  final MonitorActivityDatasource _monitorActivity;
  final MonitorBotActivityDatasource _monitorBotActivity;

  /// Catch-up del run en curso (opcional): null ⇒ el monitor arranca vacío como
  /// antes; presente ⇒ el cubit hidrata el timeline al abrir el chat.
  final MonitorCatchupDatasource? _monitorCatchup;

  /// El operador actual es ADMIN+ (gatea la observación del monitor: el endpoint
  /// SSE de actividad es ADMIN+; no abrimos el socket para roles menores).
  bool get _isAdmin {
    final s = _authBloc.state;
    return s is AuthAuthenticated && isAdminOrAbove(s.identity.role);
  }

  final PlatformAgentRepository _platformAgentRepo;
  final PlatformAgentEvents _platformAgentEvents;
  final PreviewRepository _previewRepo;
  final ResourcesRepository? _resourcesRepo;
  final NotesRepository _notesRepo;
  final AiLogRepository _aiLogRepo;

  /// Bitácora de acciones con efecto (opcional): null en tests que no navegan a
  /// la ruta; main siempre la provee.
  final AiLedgerRepository? _aiLedgerRepo;
  final ExecutionRepository _executionsRepo;
  final MembershipsRepository _membershipsRepo;
  final MembersRepository _membersRepo;
  final InvitationsRepository _invitationsRepo;
  final CatalogRepository _catalogRepo;

  /// Calendario (tipos de evento, horario, citas): alimenta la tab Agenda y las
  /// secciones de Ajustes → Agenda. Requerido — la tab Agenda vive en el shell.
  final CalendarRepository _calendarRepo;

  /// Catálogo de productos de la org (opcional): null en tests que no navegan
  /// a `/catalog/products`; main siempre lo provee.
  final ProductCatalogRepository? _productCatalogRepo;
  final CompositionRepository? _compositionRepo;

  /// Entitlement de billing (opcional): null en tests que no lo cablean —
  /// las superficies que filtran por plan degradan a no filtrar; main
  /// siempre lo provee.
  final BillingRepository? _billingRepo;

  /// Base del sitio web público (gestión de plan). Distinta de la API:
  /// `AGENTIC_BASE_URL` apunta al backend y no deriva el apex.
  final String _webBaseUrl;
  final OrgAiConfigRepository _orgAiConfigRepo;

  /// Marca de documentos de la org (opcional): null en tests que no navegan
  /// a `/org/customization`; main siempre la provee.
  final OrgBrandingRepository? _orgBrandingRepo;

  /// Ajustes del catálogo público (opcional): null en tests que no navegan a
  /// `/org/public-catalog`; main siempre la provee.
  final PublicCatalogRepository? _publicCatalogRepo;

  /// Stickers de la org (opcional): null en tests que no navegan a
  /// `/org/stickers`; main siempre la provee.
  final StickerRepository? _stickerRepo;
  final NotificationsRepository _notificationsRepo;
  final MediaRepository _mediaRepo;
  final MediaFilePicker _mediaFilePicker;

  /// Cámara del composer del hilo, singleton de la app (Noop fuera de
  /// Android): el menú de adjuntar sólo ofrece el destino si la plataforma
  /// la soporta.
  final CameraCapture _cameraCapture;
  final DeviceGalleryPort _deviceGallery;
  final MediaThumbnailLoader _mediaThumbnailLoader;
  final MediaOpener _mediaOpener;
  final MediaSharer _mediaSharer;

  /// Fabrica el motor de audio del hilo: un engine NUEVO por visita (el
  /// cubit lo dispone al cerrar la ruta; un singleton quedaría dispuesto).
  final AudioEngine Function() _audioEngineFactory;

  /// Grabador de notas de voz, singleton de la app (Noop fuera de Android).
  /// A diferencia del player, una sola instancia sirve toda la app (el
  /// plugin nativo es de instancia única) y vive el ciclo del proceso.
  final AudioRecorder _audioRecorder;

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

  /// Bytes de miniatura para la comparación antes/después de una
  /// composición. Primero el cache compartido por ref; en un miss busca el
  /// asset en la primera página de imágenes de la galería (invalidada para
  /// verla FRESCA: el resultado de un job recién terminado no existe en
  /// ningún cache local) y descarga con su URL firmada vía el resolver.
  /// Cualquier fallo ⇒ null (glifo del kit), nunca un error.
  Future<Uint8List?> _compositionThumbBytes(String ref) async {
    final cached = await ProductThumbResolver.session.load(ref);
    if (cached != null) return cached;
    MediaAsset? asset;
    try {
      _mediaRepo.invalidate();
      final page = await _mediaRepo.listAssets(type: 'image', limit: 100);
      for (final a in page.assets) {
        if (a.ref == ref) {
          asset = a;
          break;
        }
      }
    } catch (_) {
      return null;
    }
    if (asset == null) return null;
    return ProductThumbResolver.session.load(ref, asset: asset);
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthBlocListenable(_authBloc),
    redirect: _redirect,
    observers: <NavigatorObserver>[_routeObserver],
    routes: <RouteBase>[
      GoRoute(
        // El Splash mientras se resuelve la sesión; la vista de reconexión
        // cuando hay sesión persistida pero no hay red para verificarla (mismo
        // destino del redirect, contenido según el estado del AuthBloc).
        path: '/',
        builder: (context, _) => BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => state is AuthOfflinePending
              ? const ReconnectingView()
              : const SplashPage(),
        ),
      ),
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
            onSucceeded: (email) {
              // El alta persiste el par de tokens (cuenta con su org personal
              // OWNER); AuthCheckRequested dispara Authenticated. En vez de ir
              // directo al home aterrizamos en la verificación llevando el
              // correo recién registrado: la ruta se permite con sesión, así
              // que el rebote Authenticated→/home no se come esta navegación.
              _authBloc.add(const AuthCheckRequested());
              context.go(
                '/verify-email?email=${Uri.encodeQueryComponent(email)}',
              );
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
            // Aceptado el envío (202), pasa a reset llevando el correo escrito
            // para teclear ahí el código; "Ya tengo un código" va sin correo.
            onCodeSent: (email) => context.push(
              '/reset-password?email=${Uri.encodeQueryComponent(email)}',
            ),
            onHaveCode: () => context.push('/reset-password'),
          ),
        ),
      ),
      GoRoute(
        // Canjear el código de reset y fijar la nueva contraseña. Ruta pública
        // (deep-linkable). En 204 el backend revoca TODAS las familias de
        // refresh; la pantalla cierra la sesión local (AuthLoggedOut,
        // idempotente si no hay tokens) y rutea al login. El `ForgotPasswordBloc`
        // vive aquí también para el reenvío del código.
        path: '/reset-password',
        builder: (context, state) => MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ResetPasswordBloc>(
              create: (_) => ResetPasswordBloc(_authRepo),
            ),
            BlocProvider<ForgotPasswordBloc>(
              create: (_) => ForgotPasswordBloc(_authRepo),
            ),
          ],
          child: ResetPasswordPage(
            initialEmail: state.uri.queryParameters['email'] ?? '',
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
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<VerifyEmailBloc>(
                create: (_) => VerifyEmailBloc(_authRepo),
              ),
              BlocProvider<ResendVerificationCubit>(
                create: (_) => ResendVerificationCubit(_authRepo),
              ),
            ],
            // El reenvío y "omitir" sólo aplican con sesión: el reenvío exige
            // Bearer y omitir lleva al home. La página se rebuilda si la sesión
            // resuelve (p. ej. tras el AuthCheckRequested del alta).
            child: BlocBuilder<AuthBloc, AuthState>(
              bloc: _authBloc,
              builder: (context, auth) {
                final hasSession =
                    auth is AuthAuthenticated || auth is AuthAuthenticatedNoOrg;
                final page = VerifyEmailPage(
                  initialEmail: email,
                  onSucceeded: ({required bool alreadyVerified}) {
                    _authBloc.add(const AuthCheckRequested());
                    context.canPop() ? context.pop() : context.go('/home');
                  },
                  onResend: hasSession
                      ? () => context.read<ResendVerificationCubit>().resend()
                      : null,
                  onSkip: hasSession ? () => context.go('/home') : null,
                );
                // Se envuelve SIEMPRE con el BlocListener (aunque sin sesión el
                // reenvío no exista y el cubit nunca emita): así el tipo del
                // subárbol no cambia cuando la sesión resuelve y la página no se
                // remonta —no se pierde lo tecleado—. Feedback del reenvío igual
                // que el aviso del shell.
                return BlocListener<
                  ResendVerificationCubit,
                  ResendVerificationState
                >(
                  listenWhen: (_, current) =>
                      current is ResendVerificationSent ||
                      current is ResendVerificationFailed,
                  listener: (context, s) {
                    final msg = s is ResendVerificationFailed
                        ? 'No pudimos reenviar el correo. Espera un momento '
                              'para reintentar.'
                        : 'Te reenviamos el correo';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: page,
                );
              },
            ),
          );
        },
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
        builder: (context, state) {
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
          // Los repos de plantillas y bots cuelgan del scope del shell para
          // que las hojas de creación (FAB / empty-state) las construyan: un
          // bottom sheet vive fuera de este subárbol de providers, así que el
          // call site las lee aquí y las inyecta al bloc de la hoja.
          return RepositoryProvider<TemplatesRepository>.value(
            value: _templatesRepo,
            child: RepositoryProvider<BotsRepository>.value(
              value: _botsRepo,
              // Grabador de voz compartido para el composer del asistente (Noop
              // fuera de Android: el micrófono no se ofrece si no está
              // soportado). Vive sobre el subárbol keyeado por orgId: es
              // singleton de la app, independiente de la org.
              child: RepositoryProvider<AudioRecorder>.value(
                value: _audioRecorder,
                // El renderer compartido de adjuntos del asistente exige el
                // abridor de documentos y el reproductor de video en contexto;
                // como el grabador, son singletons independientes de la org.
                child: MultiRepositoryProvider(
                  providers: <RepositoryProvider<dynamic>>[
                    RepositoryProvider<MediaOpener>.value(value: _mediaOpener),
                    RepositoryProvider<VideoPlayback>.value(
                      value: const InAppVideoPlayback(),
                    ),
                  ],
                  child: KeyedSubtree(
                    key: ValueKey<String>(orgId),
                    // El borrador del wizard de creación de bot es estado de la org
                    // activa: vive DENTRO del subárbol keyeado por orgId, así un
                    // switch-org lo descarta (un borrador con la plantilla de la org
                    // A no debe asomar en la org B).
                    child: RepositoryProvider<BotCreateDraftStore>(
                      create: (_) => BotCreateDraftStore(),
                      child: MultiBlocProvider(
                        providers: <BlocProvider<dynamic>>[
                          BlocProvider<BotsBloc>(
                            create: (_) =>
                                BotsBloc(_botsRepo)
                                  ..add(const BotsLoadRequested()),
                          ),
                          // Compañero del listado de bots: al asentarse la lista,
                          // la page le pide abanicar el estado de sesión por bot.
                          // Scoped al shell, como BotsBloc, para preservar los
                          // indicadores entre cambios de tab.
                          BlocProvider<BotSessionsCubit>(
                            create: (_) => BotSessionsCubit(_botSessionRepo),
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
                          // Agenda del día, scoped al shell: la tab Agenda es
                          // lazy, así que este create (lazy por defecto) no
                          // corre —ni consulta la API— hasta la 1ª apertura de
                          // la tab; la carga del día de hoy va enganchada ahí.
                          BlocProvider<AgendaCubit>(
                            create: (_) => AgendaCubit(_calendarRepo)..load(),
                          ),
                          // Cubit del reenvío de verificación, scoped al shell para que el
                          // aviso "verifica tu correo" lo dispare y reaccione a su
                          // SnackBar.
                          BlocProvider<ResendVerificationCubit>(
                            create: (_) => ResendVerificationCubit(_authRepo),
                          ),
                          // Asistente de plataforma, scoped al shell: el dock vive
                          // sobre las 4 tabs. La carga se difiere hasta la 1ª
                          // apertura (el dock dispara PaChatStarted), sin coste en
                          // el arranque si el operador nunca lo abre.
                          BlocProvider<PlatformAgentChatBloc>(
                            create: (context) => PlatformAgentChatBloc(
                              repo: _platformAgentRepo,
                              events: _platformAgentEvents,
                              picker: FilePickerMediaFilePicker(),
                              // Siembra la copia local de cada adjunto subido y
                              // de la nota de voz grabada: el wire del asistente
                              // no trae URL firmada y la burbuja rica solo puede
                              // servirse de la caché.
                              mediaSink: context.read<MessageMediaCache>(),
                            ),
                          ),
                          // Player de audio del chat del asistente (uno por
                          // shell; el provider lo cierra y el cubit dispone el
                          // engine). Lazy: no crea engine si nunca suena nada.
                          BlocProvider<ThreadAudioCubit>(
                            create: (_) =>
                                ThreadAudioCubit(engine: _audioEngineFactory()),
                          ),
                        ],
                        // Blocs page-scoped a nivel del shell: cambiar de tab no
                        // rebuildea los providers y cada lista preserva estado
                        // (Loaded, refresh, failures) entre Bots ⇄ Plantillas ⇄ Ajustes.
                        // El routeObserver se atraviesa al shell para que ambos list
                        // pages disparen su refresh al volver de una sub-ruta.
                        child: ShellPage(
                          routeObserver: _routeObserver,
                          assistantDraft:
                              state.uri.queryParameters['prompt'] ?? '',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<BotDetailBloc>(
                  create: (_) =>
                      BotDetailBloc(repo: _botsRepo, id: id)
                        ..add(const BotDetailLoadRequested()),
                ),
                // Estado vivo de la sesión para el hero de conexión: carga
                // al montar y sondea mientras el detalle está abierto (al
                // volver de /connect el hub se refresca solo).
                BlocProvider<BotSessionStatusBloc>(
                  create: (_) =>
                      BotSessionStatusBloc(repo: _botSessionRepo, botId: id)
                        ..add(const BotSessionStatusStarted()),
                ),
              ],
              // Sin AppBar: el header full-bleed con gradiente ES el encabezado
              // (la página aporta su propio retorno en los tres estados).
              child: const Scaffold(body: BotDetailPage()),
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
              appBar: AppBar(title: const Text('Variables del Canal')),
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
          // Los repos de etiquetas cuelgan del scope para el sheet de etiquetas
          // por chat (la fila de la bandeja lo abre con su chatLid + kind): las
          // etiquetas WhatsApp (sección "WhatsApp" + mapeos) y los Labels
          // internos puestos al chat (sección "Internas", solo lectura).
          return MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<WaLabelsRepository>.value(
                value: _waLabelsRepo,
              ),
              RepositoryProvider<ChatLabelsRepository>.value(
                value: _chatLabelsRepo,
              ),
            ],
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ConversationsBloc>(
                  create: (_) =>
                      ConversationsBloc(repo: _conversationsRepo, botId: id)
                        ..add(const ConversationsLoadRequested()),
                ),
                // Señales de atención del bot (falló/alerta) por chat: tier
                // operador (WORKER+), feed bot-scoped. Destaca filas en la bandeja.
                BlocProvider<MonitorAttentionCubit>(
                  create: (_) =>
                      MonitorAttentionCubit(_monitorBotActivity)..watch(id),
                ),
                // Etiquetas WhatsApp del bot para la bandeja: blobs por chat y
                // chips de filtro. Carga al montar y se queda en vivo (feed
                // `label.wa.*`) para reflejar etiquetados sin recargar; degrada
                // a vacío si falla.
                BlocProvider<InboxLabelsCubit>(
                  create: (_) =>
                      InboxLabelsCubit(repo: _waLabelsRepo, botId: id)
                        ..watchLive(),
                ),
              ],
              child: Scaffold(
                appBar: AppBar(title: const Text('Conversaciones')),
                body: BlocBuilder<MonitorAttentionCubit, MonitorAttentionState>(
                  builder: (context, attn) => ConversationsListPage(
                    needsAttention: attn.needsAttention,
                  ),
                ),
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
          // El repo y el picker de media cuelgan del scope para que el composer
          // adjunte imágenes (pick → upload → ref → send type:image). El repo de
          // etiquetas WA cuelga para el sheet de etiquetas por chat del app bar.
          return MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<MediaRepository>.value(value: _mediaRepo),
              RepositoryProvider<MediaFilePicker>.value(
                value: _mediaFilePicker,
              ),
              // Cámara para el destino "Cámara" del menú de adjuntar (Noop
              // fuera de Android: el destino no se ofrece si no hay soporte).
              RepositoryProvider<CameraCapture>.value(value: _cameraCapture),
              // Carrete del teléfono para la previsualización de Galería del
              // menú de adjuntar (Noop fuera de Android: se oculta).
              RepositoryProvider<DeviceGalleryPort>.value(
                value: _deviceGallery,
              ),
              // Grabador de notas de voz para el composer (Noop fuera de
              // Android: el botón 🎤 no se ofrece si no está soportado).
              RepositoryProvider<AudioRecorder>.value(value: _audioRecorder),
              RepositoryProvider<WaLabelsRepository>.value(
                value: _waLabelsRepo,
              ),
              RepositoryProvider<ChatLabelsRepository>.value(
                value: _chatLabelsRepo,
              ),
              RepositoryProvider<FlowRunRepository>.value(value: _flowRunRepo),
              RepositoryProvider<NotesRepository>.value(value: _notesRepo),
              // Abre documentos del hilo con una app externa.
              RepositoryProvider<MediaOpener>.value(value: _mediaOpener),
              // Comparte media del hilo con otras apps (share sheet).
              RepositoryProvider<MediaSharer>.value(value: _mediaSharer),
              // Reproduce videos del hilo a pantalla completa dentro de la app.
              RepositoryProvider<VideoPlayback>.value(
                value: const InAppVideoPlayback(),
              ),
              // Toma del chat (S25): resolver las etiquetas de silencio del bot
              // exige bot→plantilla; el sheet del app bar las compone.
              RepositoryProvider<BotsRepository>.value(value: _botsRepo),
              RepositoryProvider<TemplatesRepository>.value(
                value: _templatesRepo,
              ),
            ],
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<MessagesBloc>(
                  create: (_) => MessagesBloc(
                    repo: _messagesRepo,
                    botId: id,
                    chatLid: chatLid,
                  )..add(const MessagesLoadRequested()),
                ),
                // Player de audio del hilo (uno por visita; el provider lo
                // cierra al salir y el cubit dispone el engine).
                BlocProvider<ThreadAudioCubit>(
                  create: (_) =>
                      ThreadAudioCubit(engine: _audioEngineFactory()),
                ),
                // Catálogo de respuestas rápidas WhatsApp del bot: carga al abrir
                // el hilo para que el selector ⚡ del composer las ofrezca.
                BlocProvider<QuickRepliesBloc>(
                  create: (_) =>
                      QuickRepliesBloc(repo: _quickRepliesRepo, botId: id)
                        ..add(const QuickRepliesLoadRequested()),
                ),
                // El perfil alimenta el header (avatar + nombre real) y se
                // re-monta en la pantalla de perfil; dos cargas hoy, la cache
                // RFC-0001 las absorberá.
                BlocProvider<ProfileBloc>(
                  create: (_) => ProfileBloc(
                    repo: _profileRepo,
                    botId: id,
                    chatLid: chatLid,
                  )..add(const ProfileLoadRequested()),
                ),
                // Actividad EN VIVO del bot runtime (footer + píldora de estado).
                // Solo ADMIN+ abre el SSE (el endpoint es ADMIN+); para roles
                // menores el cubit queda inerte y el footer no se pinta.
                BlocProvider<MonitorLiveCubit>(
                  create: (_) {
                    final cubit = MonitorLiveCubit(
                      _monitorActivity,
                      catchup: _monitorCatchup,
                    );
                    if (_isAdmin) cubit.watch(id, chatLid);
                    return cubit;
                  },
                ),
              ],
              child: Scaffold(
                appBar: ChatThreadAppBar(botId: id, chatLid: chatLid),
                // El badge de cita cuelga sobre el hilo: carga perezosa y
                // silenciosa (si no hay cita futura confirmada, no ocupa
                // espacio). Se construye su propio cubit desde el repo.
                body: Column(
                  children: <Widget>[
                    ChatAppointmentBadge(
                      repository: _calendarRepo,
                      botId: id,
                      chatLid: chatLid,
                    ),
                    const Expanded(child: MessageThreadPage()),
                  ],
                ),
              ),
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
        // Observabilidad del bot (S12): el ai-log del chat dividido por
        // corrida del motor. Sub-ruta del hilo (segmento `/ai-log` extra).
        // El backend la protege con ADMIN+ (la entrada del app bar también
        // se oculta para roles menores); page-scoped: `AiLogBloc` carga la
        // primera página al montarse.
        path: '/bots/:id/sessions/:chatLid/ai-log',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final chatLid = state.pathParameters['chatLid']!;
          // `?msg=<wamid>` = drill-through inverso: muestra SOLO la corrida que
          // produjo ese OUTBOUND. `?run=<id>` = drill directo por corrida
          // (badge de la burbuja / pill de fallo), sin resolver el wamid.
          // Ausentes = log completo de la sesión.
          final msg = state.uri.queryParameters['msg'];
          final run = state.uri.queryParameters['run'];
          return BlocProvider<AiLogBloc>(
            create: (_) => AiLogBloc(
              repo: _aiLogRepo,
              botId: id,
              chatLid: chatLid,
              targetExternalId: msg,
              targetRunId: run,
            )..add(const AiLogLoadRequested()),
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  run != null
                      ? 'Razonamiento de la corrida'
                      : (msg == null
                            ? 'Razonamiento del Asistente'
                            : 'Razonamiento de este mensaje'),
                ),
              ),
              body: const AiLogPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Bitácora de acciones con efecto del chat (S30): SÓLO lo que el bot
        // CAMBIÓ, en texto de negocio. Sub-ruta del hilo (segmento `/ai-ledger`
        // extra). ADMIN+ en backend (la entrada del app bar se oculta a roles
        // menores); page-scoped, carga al montarse.
        path: '/bots/:id/sessions/:chatLid/ai-ledger',
        builder: (context, state) {
          final repo = _aiLedgerRepo;
          if (repo == null) {
            return const Scaffold(body: SizedBox.shrink());
          }
          final id = state.pathParameters['id']!;
          final chatLid = state.pathParameters['chatLid']!;
          return BlocProvider<AiLedgerBloc>(
            create: (_) =>
                AiLedgerBloc(repo: repo, botId: id, chatLid: chatLid)
                  ..add(const AiLedgerLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Bitácora de acciones')),
              body: const AiLedgerPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Historial de ejecuciones de flujo del chat (S11): qué corrió, con
        // qué estado y por qué falló. Sub-ruta del hilo (segmento extra). El
        // backend la protege con ADMIN+ (la entrada del app bar también se
        // oculta para roles menores); page-scoped, carga al montarse. Resuelve
        // los nombres de flujo contra el catálogo corrible (best-effort).
        path: '/bots/:id/sessions/:chatLid/executions',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final chatLid = state.pathParameters['chatLid']!;
          return BlocProvider<ExecutionsCubit>(
            create: (_) => ExecutionsCubit(
              execRepo: _executionsRepo,
              flowRunRepo: _flowRunRepo,
              botId: id,
              chatLid: chatLid,
            )..load(),
            child: Scaffold(
              appBar: AppBar(title: const Text('Ejecuciones del chat')),
              body: const ExecutionsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/assistants/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // El repo de bots cuelga del scope para que el CTA "Crear bot" del
          // detalle abra la hoja de creación (con esta plantilla ya elegida)
          // sin reconsultar el backend ni navegar a una pantalla aparte.
          return RepositoryProvider<BotsRepository>.value(
            value: _botsRepo,
            child: MultiBlocProvider(
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
                BlocProvider<BotsBloc>(
                  create: (_) =>
                      BotsBloc(_botsRepo)..add(const BotsLoadRequested()),
                ),
              ],
              // Sin AppBar: el header de gradiente full-bleed de la página
              // aporta retorno + editar, y el Entrenador entra por su card
              // hero en el cuerpo (ya no es un icono escondido de AppBar).
              child: const Scaffold(body: TemplateDetailPage()),
            ),
          );
        },
      ),
      GoRoute(
        path: '/assistants/:id/channels',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RepositoryProvider<BotsRepository>.value(
            value: _botsRepo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<TemplateDetailBloc>(
                  create: (_) =>
                      TemplateDetailBloc(repo: _templatesRepo, id: id)
                        ..add(const TemplateDetailLoadRequested()),
                ),
                BlocProvider<BotsBloc>(
                  create: (_) =>
                      BotsBloc(_botsRepo)..add(const BotsLoadRequested()),
                ),
              ],
              child: AssistantChannelsPage(assistantId: id),
            ),
          );
        },
      ),
      GoRoute(
        path: '/assistants/:id/resources',
        builder: (context, state) {
          final repo = _resourcesRepo;
          if (repo == null) {
            return const Scaffold(
              body: Center(
                child: Text('Biblioteca no disponible en este entorno.'),
              ),
            );
          }
          final id = state.pathParameters['id']!;
          return BlocProvider<AssistantResourcesCubit>(
            create: (_) =>
                AssistantResourcesCubit(repository: repo, assistantId: id)
                  ..load(),
            child: AssistantResourcesPage(
              assistantName: state.uri.queryParameters['name'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/assistants/:id/preview',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<PreviewBloc>(
            create: (_) => PreviewBloc(
              repo: _previewRepo,
              templateId: id,
              picker: FilePickerMediaFilePicker(),
            )..add(const PreviewStarted()),
            child: PreviewPage(templateId: id),
          );
        },
      ),
      // Compatibilidad de deep links durante el rollout. El usuario aterriza
      // en la IA nueva sin perder marcadores ni enlaces de versiones previas.
      GoRoute(
        path: '/templates/:id',
        redirect: (_, state) => '/assistants/${state.pathParameters['id']!}',
      ),
      GoRoute(
        path: '/templates/:id/trainer/preview',
        redirect: (_, state) =>
            '/assistants/${state.pathParameters['id']!}/preview',
      ),
      GoRoute(
        // Lista de flujos de la plantilla con buscador local. Página
        // dedicada (el hub solo muestra count + caption): inline en el
        // detalle, decenas de flujos lo volvían inusable.
        path: '/templates/:id/flows',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // La página posee su Scaffold (AppBar + FAB); la ruta provee los
          // blocs y el repo que el form-sheet de alta lee en el call site.
          // TriggersBloc alimenta el count de disparadores por tarjeta
          // (un GET por template, no por flujo).
          return RepositoryProvider<FlowsRepository>.value(
            value: _flowsRepo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
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
              child: TemplateFlowsPage(templateId: id),
            ),
          );
        },
      ),
      GoRoute(
        // Variables (var-defs) de la plantilla con buscador local. Misma
        // motivación que /flows: las listas largas viven en su página.
        path: '/templates/:id/variables',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<VarDefsBloc>(
            create: (_) =>
                VarDefsBloc(repo: _templatesRepo, templateId: id)
                  ..add(const VarDefsLoadRequested()),
            child: const TemplateVariablesPage(),
          );
        },
      ),
      GoRoute(
        // Motor IA de la plantilla: stats + prompt (card colapsada) + CTA al
        // entrenador. Saca la config del fondo del detalle a su escenario. El
        // Scaffold + AppBar planos los monta aquí el router (content-only en la
        // página), la misma anatomía que la config de IA de la org.
        path: '/templates/:id/ai',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final billingRepo = _billingRepo;
          // CatalogBloc alimenta el picker de modelo y las capacidades
          // (temperatura/razonamiento) que gobiernan qué tiles editan.
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<TemplateDetailBloc>(
                create: (_) =>
                    TemplateDetailBloc(repo: _templatesRepo, id: id)
                      ..add(const TemplateDetailLoadRequested()),
              ),
              BlocProvider<CatalogBloc>(
                create: (_) =>
                    CatalogBloc(_catalogRepo)
                      ..add(const CatalogLoadRequested()),
              ),
              // Entitlement del plan: filtra el picker de cerebro a los
              // proveedores elegibles. Sin repo, la página no filtra.
              if (billingRepo != null)
                BlocProvider<EntitlementBloc>(
                  create: (_) =>
                      EntitlementBloc(billingRepo)
                        ..add(const EntitlementLoadRequested()),
                ),
              // Catálogo org-scoped para el multi-select de etiquetas de
              // silencio; carga única, compartida con el sheet por value.
              BlocProvider<LabelsBloc>(
                create: (_) =>
                    LabelsBloc(repo: _labelsRepo)
                      ..add(const LabelsLoadRequested()),
              ),
            ],
            child: Scaffold(
              appBar: AppBar(title: const Text('Motor IA')),
              body: const TemplateAiPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Config de IA a nivel ORG (ADMIN/OWNER): proveedor por modelo +
        // defaults de plantillas nuevas. El gate de la tile en Settings es
        // cosmético; la autoridad real es el 403 del backend (cae en
        // OrgAiConfigLoadFailed → "sin permiso"). CatalogBloc alimenta los
        // hosts seleccionables y el picker de modelo de los defaults. La
        // acción Guardar vive en el AppBar: la pantalla edita varios campos
        // que viajan juntos en UN PUT, así que el guardado es explícito.
        path: '/org/ai-config',
        builder: (context, state) {
          final billingRepo = _billingRepo;
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<OrgAiConfigBloc>(
                create: (_) =>
                    OrgAiConfigBloc(_orgAiConfigRepo)
                      ..add(const OrgAiConfigLoadRequested()),
              ),
              BlocProvider<CatalogBloc>(
                create: (_) =>
                    CatalogBloc(_catalogRepo)
                      ..add(const CatalogLoadRequested()),
              ),
              // Entitlement del plan: filtra el picker de los defaults a los
              // proveedores elegibles. Sin repo, la pantalla no filtra.
              if (billingRepo != null)
                BlocProvider<EntitlementBloc>(
                  create: (_) =>
                      EntitlementBloc(billingRepo)
                        ..add(const EntitlementLoadRequested()),
                ),
            ],
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Configuración de IA'),
                actions: const <Widget>[OrgAiConfigSaveAction()],
              ),
              body: const OrgAiConfigPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Editor de un flow (S11): hub content-only — el cuerpo es la
        // lista de pasos; Disparadores y Configuración viven en subrutas.
        // La ruta es de primer nivel, deep-linkable (consistente con
        // /templates/:id, /bots/:id). El back físico vuelve al listado de
        // flujos si se llegó por ahí, o al destino previo en deep-link.
        // El AppBar muestra el NOMBRE del flujo y el menú ⋮ (renombrar,
        // pausar/activar) — ambos leen el FlowDetailBloc del scope.
        path: '/flows/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // `TriggersRepository` alimenta el count de la fila launcher de
          // Disparadores; `LabelsRepository`, el LabelsBloc del listado y
          // el selector del paso LABEL en el sheet de pasos.
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
                // Catálogo de labels para que la lista de pasos muestre el
                // NOMBRE de la etiqueta del paso LABEL (no el UUID). Scope de
                // página: no interfiere con los LabelsBloc efímeros que crean
                // los sheets (subtrees propios).
                BlocProvider<LabelsBloc>(
                  create: (_) =>
                      LabelsBloc(repo: _labelsRepo)
                        ..add(const LabelsLoadRequested()),
                ),
              ],
              child: Scaffold(
                appBar: AppBar(
                  title: const FlowDetailTitle(),
                  actions: const <Widget>[FlowDetailMenuAction()],
                ),
                body: const FlowDetailPage(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        // Disparadores del flujo. Sub-ruta de `/flows/:id` con un segmento
        // más, así no compite con el hub por orden de match. Blocs a nivel
        // de ruta: el listado se pide una vez por visita (adiós refetch
        // por tab). La página resuelve la cabecera con su FlowDetailBloc
        // propio (el endpoint de triggers es template-scoped y el sheet
        // exige el Flow entero).
        path: '/flows/:id/triggers',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<TriggersRepository>.value(
                value: _triggersRepo,
              ),
              RepositoryProvider<LabelsRepository>.value(value: _labelsRepo),
            ],
            child: BlocProvider<FlowDetailBloc>(
              create: (_) =>
                  FlowDetailBloc(repo: _flowsRepo, id: id)
                    ..add(const FlowDetailLoadRequested()),
              child: Scaffold(
                appBar: AppBar(title: const Text('Disparadores')),
                body: const FlowTriggersPage(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        // Configuración del flujo (gates + allowlist IA). Sub-ruta de
        // `/flows/:id`. El FlowDetailBloc es de la ruta: el form dirty
        // sobrevive mientras la página esté en el stack.
        path: '/flows/:id/settings',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BlocProvider<FlowDetailBloc>(
            create: (_) =>
                FlowDetailBloc(repo: _flowsRepo, id: id)
                  ..add(const FlowDetailLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Configuración')),
              body: const FlowSettingsPage(),
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
            // Invitaciones pendientes del operador (best-effort, sección extra
            // arriba de la lista). Carga sola; oculta si no hay o si falla.
            BlocProvider<PendingInvitationsCubit>(
              create: (_) => PendingInvitationsCubit(_authRepo)..load(),
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
            appBar: AppBar(title: const Text('Asignar Canales')),
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
        // Preferencias visuales del dispositivo (animaciones). Sin bloc
        // page-scoped: el MotionSettingsCubit es global (lo proyecta
        // AtaulfoApp sobre toda la app).
        path: '/appearance',
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Apariencia')),
          body: const AppearancePage(),
        ),
      ),
      GoRoute(
        // Personalización de la organización: nombre + logo de los
        // documentos del asistente. Entry point: tile admin-gated en
        // SettingsPage (gate cosmético; el backend 403ea por debajo de
        // ADMIN). Page-scoped: el cubit carga marca + nombre al montarse;
        // RenameOrgCubit reusa el mismo flujo de renombrar de memberships.
        path: '/org/customization',
        builder: (context, _) {
          final brandingRepo = _orgBrandingRepo;
          if (brandingRepo == null) {
            return const Scaffold(
              body: Center(child: Text('Personalización no disponible')),
            );
          }
          final auth = _authBloc.state;
          final activeOrgId = auth is AuthAuthenticated
              ? auth.identity.orgId
              : '';
          return MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<OrgCustomizationCubit>(
                create: (_) => OrgCustomizationCubit(
                  branding: brandingRepo,
                  memberships: _membershipsRepo,
                  activeOrgId: activeOrgId,
                )..load(),
              ),
              BlocProvider<RenameOrgCubit>(
                create: (_) => RenameOrgCubit(_authRepo),
              ),
            ],
            child: Scaffold(
              appBar: AppBar(title: const Text('Personalización')),
              body: const OrgCustomizationPage(),
            ),
          );
        },
      ),
      GoRoute(
        // Catálogo público de la org (Arco D): encender la vitrina, elegir el
        // enlace y copiar la URL. ADMIN+ (el backend lo hace cumplir).
        // Page-scoped: el cubit carga los ajustes al montarse.
        path: '/org/public-catalog',
        builder: (context, _) {
          final repo = _publicCatalogRepo;
          if (repo == null) {
            return const Scaffold(
              body: Center(child: Text('Catálogo público no disponible')),
            );
          }
          return BlocProvider<PublicCatalogCubit>(
            create: (_) => PublicCatalogCubit(repo)..load(),
            child: const PublicCatalogPage(),
          );
        },
      ),
      GoRoute(
        // Stickers corporativos (Arco E): generar stickers de motivos curados y
        // ver la galería. ADMIN+ (el backend lo hace cumplir). Los thumbnails
        // se resuelven por el mismo camino que el «después» de la composición
        // (galería fresca + URL firmada).
        path: '/org/stickers',
        builder: (context, _) {
          final repo = _stickerRepo;
          if (repo == null) {
            return const Scaffold(
              body: Center(child: Text('Stickers no disponible')),
            );
          }
          return BlocProvider<StickerCubit>(
            create: (_) => StickerCubit(repo)..load(),
            child: StickersPage(resolveThumb: _compositionThumbBytes),
          );
        },
      ),
      GoRoute(
        // Selector de stickers para el chat (Arco E): elige un sticker LISTO y
        // devuelve su ref al composer, que lo envía al instante. Mismo repo y
        // resolutor de thumbnails que la pantalla de Ajustes; sin generar aquí.
        path: '/stickers/pick',
        builder: (context, _) {
          final repo = _stickerRepo;
          if (repo == null) {
            return const Scaffold(
              body: Center(child: Text('Stickers no disponible')),
            );
          }
          return BlocProvider<StickerCubit>(
            create: (_) => StickerCubit(repo)..load(),
            child: StickerPickerPage(resolveThumb: _compositionThumbBytes),
          );
        },
      ),
      GoRoute(
        // Cuenta y plan de la org, SOLO-LECTURA: gestionar (contratar,
        // mejorar, pagar) vive en el sitio web y la página solo enlaza.
        // Entry point: tile admin-gated en SettingsPage (gate cosmético,
        // como Configuración de IA). Page-scoped: el bloc carga el
        // entitlement al montarse; un retry desde Failed reusa el load.
        path: '/cuenta',
        builder: (context, _) {
          final billingRepo = _billingRepo;
          if (billingRepo == null) {
            return const Scaffold(
              body: Center(child: Text('Cuenta no disponible')),
            );
          }
          return BlocProvider<EntitlementBloc>(
            create: (_) =>
                EntitlementBloc(billingRepo)
                  ..add(const EntitlementLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Cuenta')),
              body: CuentaPage(
                webBaseUrl: _webBaseUrl,
                launcher: const UrlLauncherWebLinkLauncher(),
              ),
            ),
          );
        },
      ),
      GoRoute(
        // Reserva manual de una cita. Entry point: FAB de la tab Agenda.
        // Page-scoped: el BookingCubit se construye con el repo y carga los
        // tipos de evento activos al montarse. Al crear con éxito hace
        // pop(true) y la agenda recarga.
        path: '/agenda/book',
        builder: (context, _) => BlocProvider<BookingCubit>(
          create: (_) => BookingCubit(_calendarRepo)..loadEventTypes(),
          child: Scaffold(
            appBar: AppBar(title: const Text('Nueva cita')),
            body: const BookingPage(),
          ),
        ),
      ),
      GoRoute(
        // Ajustes → Agenda → Tipos de cita (CRUD). Entry point: tile ADMIN+ en
        // SettingsPage. Page-scoped: carga los tipos al montarse.
        path: '/calendar/event-types',
        builder: (context, _) => BlocProvider<EventTypesCubit>(
          create: (_) => EventTypesCubit(_calendarRepo)..load(),
          child: Scaffold(
            appBar: AppBar(title: const Text('Tipos de cita')),
            body: const EventTypesPage(),
          ),
        ),
      ),
      GoRoute(
        // Ajustes → Agenda → Horario de atención (editor semanal). Entry point:
        // tile ADMIN+ en SettingsPage. Page-scoped: carga el horario al montar.
        path: '/calendar/hours',
        builder: (context, _) => BlocProvider<BusinessHoursCubit>(
          create: (_) => BusinessHoursCubit(_calendarRepo)..load(),
          child: Scaffold(
            appBar: AppBar(title: const Text('Horario de atención')),
            body: const BusinessHoursPage(),
          ),
        ),
      ),
      GoRoute(
        // Ajustes → Catálogo de productos (listado + búsqueda + alta/edición).
        // Entry point: tile para todo miembro en SettingsPage (leer es de
        // cualquier rol; crear/editar lo autoriza el backend con 403).
        // Page-scoped: carga productos y categorías al montarse. El FAB de
        // alta vive en el Scaffold de la ruta, bajo el mismo provider.
        path: '/catalog/products',
        builder: (context, _) {
          final repo = _productCatalogRepo;
          if (repo == null) {
            return const Scaffold(
              body: Center(child: Text('Catálogo no disponible')),
            );
          }
          final compositionRepo = _compositionRepo;
          return BlocProvider<ProductCatalogCubit>(
            create: (_) => ProductCatalogCubit(repo)..load(),
            child: Scaffold(
              appBar: AppBar(title: const Text('Catálogo de productos')),
              body: ProductCatalogPage(
                // «Mejorar foto con IA» solo si el wiring trae el repo de
                // composición; sin él la edición no ofrece la acción.
                composePhoto: compositionRepo == null
                    ? null
                    : (context, product) => ComposePhotoSheet.open(
                        context,
                        product: product,
                        repo: compositionRepo,
                        thumbBytes: _compositionThumbBytes,
                      ),
              ),
              floatingActionButton: const ProductCatalogFab(),
            ),
          );
        },
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
            // "Medios": el mismo término con el que el menú de adjuntar del
            // chat nombra este catálogo de la organización.
            appBar: AppBar(title: const Text('Medios')),
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
          // `?readOnly=1` = PREVIEW desde el picker: mirar sin mutar (oculta
          // renombrar/borrar). Browse abre sin el flag y conserva las acciones.
          // VideoPlayback + ThreadAudioCubit: el detalle reproduce video/audio
          // DENTRO de la app (mismo reproductor que los hilos de chat), no vía
          // el visor externo del sistema. El chrome (Scaffold + AppBar con el
          // título vivo del cubit) lo monta la ruta; la página es content-only
          // y las mutaciones viven en su superficie (fila de alias + zona
          // peligrosa), así que el AppBar no carga acciones.
          return MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<VideoPlayback>.value(
                value: const InAppVideoPlayback(),
              ),
            ],
            child: BlocProvider<ThreadAudioCubit>(
              create: (_) => ThreadAudioCubit(engine: _audioEngineFactory()),
              child: BlocProvider<MediaDetailCubit>(
                create: (_) => MediaDetailCubit(repo: _mediaRepo, asset: asset),
                child: Scaffold(
                  appBar: AppBar(title: const MediaDetailTitle()),
                  body: MediaDetailPage(
                    loader: _mediaThumbnailLoader,
                    launcher: const UrlLauncherMediaPreviewLauncher(),
                    readOnly: state.uri.queryParameters['readOnly'] == '1',
                  ),
                ),
              ),
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
          // galería completa CON tabs de familia (no hay restricción que
          // proteger). `?multi=1` activa la multi-selección: el pop devuelve
          // List<MediaAsset> (composer del chat); sin él, un solo MediaAsset
          // (pasos de flujo). En ambos, el asset vuelve ENTERO (ref +
          // content_type + filename) y el caller persiste sólo el ref BARE.
          // El long-press abre el detalle como preview de solo lectura.
          final type = state.uri.queryParameters['type'];
          final multi = state.uri.queryParameters['multi'] == '1';
          return BlocProvider<MediaGalleryBloc>(
            create: (_) => MediaGalleryBloc(
              repo: _mediaRepo,
              picker: _mediaFilePicker,
              type: type,
            )..add(const MediaGalleryLoadRequested()),
            child: Scaffold(
              appBar: AppBar(title: const Text('Elegir multimedia')),
              body: MediaGalleryPage(
                onSelect: multi ? null : (asset) => context.pop(asset),
                onConfirmSelection: multi
                    ? (assets) => context.pop(assets)
                    : null,
                onOpenDetail: (asset) async =>
                    (await context.push<bool>(
                      '/media/detail?readOnly=1',
                      extra: asset,
                    )) ??
                    false,
                loader: _mediaThumbnailLoader,
                showTypeTabs: type == null,
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
    case AuthOfflinePending():
      // Misma política que el arranque: con sesión persistida pero sin red para
      // verificarla, se sostiene en `/` (que pinta la vista de reconexión) en
      // vez de mandar al login. Las rutas públicas se preservan por si el
      // operador quiere ir a login a propósito.
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
