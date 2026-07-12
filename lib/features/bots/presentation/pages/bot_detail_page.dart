import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_danger_zone.dart';
import '../../../../core/design/widgets/app_section_link.dart';
import '../../../../core/design/widgets/app_toggle_row.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_detail_bloc.dart';
import '../widgets/bot_ai_toggle.dart';
import '../widgets/bot_clone_sheet.dart';
import '../widgets/bot_connection_card.dart';
import '../widgets/bot_detail_header.dart';
import '../widgets/bot_edit_sheet.dart';
import '../widgets/bot_group_gates.dart';
import '../widgets/bot_tool_permissions.dart';

/// Detalle de un Bot (S04): el HUB del bot. Identidad en el header de
/// gradiente, la conexión del canal como card hero (estado vivo — lo
/// primero que el operador necesita saber), las áreas (conversaciones,
/// etiquetas WA, variables, mantenimiento) como filas launcher hacia sus
/// páginas, y los controles de mutación agrupados en una card. Consume el
/// `BotDetailBloc` y el `BotSessionStatusBloc` del scope; el cableado lo
/// hace el router en `/bots/:id`. Content-only: el Scaffold lo aporta la
/// ruta (sin AppBar — el header aporta retorno y editar).
///
/// Centro de mando: WORKER ve el detalle (la ruta es WORKER+), pero todos
/// los controles de mutación están gateados ADMIN+ leyendo `Identity.role`
/// del `AuthBloc` global. El gateo es cosmético; la autoridad real es el
/// 403 del backend.
class BotDetailPage extends StatelessWidget {
  const BotDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAdmin =
        authState is AuthAuthenticated &&
        isAdminOrAbove(authState.identity.role);
    return BlocListener<BotDetailBloc, BotDetailState>(
      listenWhen: (_, current) => current is BotDetailDeleteSucceeded,
      listener: (context, state) {
        // Borrado: vuelve a la lista (que se refresca vía el RouteObserver).
        // `maybePop` sobre el Navigator raíz (el mismo que usa go_router) hace
        // pop sólo si hay algo debajo — robusto en pruebas y en la app real.
        Navigator.of(context).maybePop();
      },
      child: BlocBuilder<BotDetailBloc, BotDetailState>(
        builder: (context, state) => switch (state) {
          BotDetailLoading() => const _LoadingView(),
          BotDetailLoaded(bot: final bot) => _LoadedView(
            bot: bot,
            isAdmin: isAdmin,
          ),
          // Durante una mutación el bot sigue visible con los controles
          // inhabilitados; tras un fallo, visible con el copy de error.
          BotDetailMutating(bot: final bot) => _LoadedView(
            bot: bot,
            isAdmin: isAdmin,
            isMutating: true,
          ),
          BotDetailMutationFailed(bot: final bot, failure: final f) =>
            _LoadedView(bot: bot, isAdmin: isAdmin, failure: f),
          // Transitorios: el listener ya navegó (clon) o hizo pop (borrado);
          // un frame de spinner evita parpadeo mientras se desmonta.
          BotDetailCloneSucceeded() => const _LoadingView(),
          BotDetailDeleteSucceeded() => const _LoadingView(),
          BotDetailFailed(failure: final f) => _FailedView(failure: f),
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const _BackScaffold(
    child: Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
      ),
    ),
  );
}

/// Envuelve los estados sin header (carga/error) con un retorno claro arriba a
/// la izquierda. La ruta ya no aporta AppBar; sin esto el operador quedaría
/// atrapado si la carga cuelga o el bot falla. El glifo va en color de texto
/// (no el círculo oscuro del header) para leerse sobre el fondo oscuro.
class _BackScaffold extends StatelessWidget {
  const _BackScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back, color: AppTokens.text1),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.bot,
    required this.isAdmin,
    this.isMutating = false,
    this.failure,
  });

  final Bot bot;

  /// El operador alcanza ADMIN+ → ve y opera los controles de mutación.
  final bool isAdmin;

  /// Hay un PUT en vuelo → los controles quedan inhabilitados.
  final bool isMutating;

  /// Última mutación fallida (copy inline en danger). Null = sin error.
  final BotsFailure? failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final f = failure;
    return SingleChildScrollView(
      // Sin padding aquí: el header es full-bleed y va pegado arriba. El resto
      // del contenido lleva su propio padding más abajo.
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BotDetailHeader(
            name: bot.name,
            channelLabel: _channelLabel(bot.channel),
            version: bot.version,
            paused: bot.paused,
            aiDisabled: bot.aiDisabled,
            identifier: bot.identifier,
            onBack: () => Navigator.of(context).maybePop(),
            showEdit: isAdmin,
            onEdit: isMutating
                ? null
                : () => BotEditSheet.openEdit(context, bot),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6,
              AppTokens.sp6 + context.safeBottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Versión, estado, IA e identificador viven EN el header
                // (cápsulas glass). Aquí abajo: conexión → áreas → controles.
                BotConnectionCard(bot: bot),
                const SizedBox(height: AppTokens.sp6),
                _SectionLauncher(bot: bot, isAdmin: isAdmin),
                if (isAdmin) ...<Widget>[
                  const SizedBox(height: AppTokens.sp6),
                  AppCard(
                    key: const Key('bot_detail.card.controls'),
                    child: Column(
                      children: <Widget>[
                        AppToggleRow(
                          switchKey: const Key('bot_detail.paused'),
                          label: 'Pausar bot',
                          caption:
                              'Pausado, el bot deja de procesar mensajes '
                              'hasta que lo reanudes; no se reanuda solo.',
                          value: bot.paused,
                          onChanged: isMutating
                              ? null
                              : (v) => context.read<BotDetailBloc>().add(
                                  BotDetailUpdateRequested(paused: v),
                                ),
                        ),
                        const Divider(
                          height: AppTokens.sp5,
                          color: AppTokens.divider,
                        ),
                        BotAiToggle(bot: bot, isMutating: isMutating),
                        const Divider(
                          height: AppTokens.sp5,
                          color: AppTokens.divider,
                        ),
                        BotToolPermissions(bot: bot, isMutating: isMutating),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.sp6),
                  // Subsección con contexto propio: card aparte, no una fila
                  // más de la lista plana de controles.
                  BotGroupGates(bot: bot, isMutating: isMutating),
                ],
                if (f != null) ...<Widget>[
                  const SizedBox(height: AppTokens.sp4),
                  Text(
                    _failureMessage(f),
                    key: const Key('bot_detail.mutation_error'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTokens.danger,
                    ),
                  ),
                ],
                if (isAdmin) ...<Widget>[
                  const SizedBox(height: AppTokens.sp7),
                  // Clonar crea un bot nuevo sin tocar el actual: es gestión
                  // de ciclo de vida, no una acción destructiva, así que va
                  // FUERA de la zona peligrosa.
                  AppButton.tonal(
                    key: const Key('bot_detail.clone'),
                    label: 'Clonar bot',
                    fullWidth: true,
                    onPressed: isMutating
                        ? null
                        : () => BotCloneSheet.open(
                            context,
                            onCloned: (newId) => context.push('/bots/$newId'),
                          ),
                  ),
                  const SizedBox(height: AppTokens.sp7),
                  AppDangerZone(
                    caption:
                        'Eliminar el bot es permanente: sus conversaciones, '
                        'mensajes y ejecuciones quedan huérfanos. Si quieres '
                        'limpiarlos, usa Mantenimiento antes.',
                    actions: <Widget>[
                      AppButton.danger(
                        key: const Key('bot_detail.delete'),
                        label: 'Eliminar bot',
                        fullWidth: true,
                        onPressed: isMutating
                            ? null
                            : () => _confirmDelete(context, bot),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Confirmación fuerte (Tier B) antes de borrar. Avisa de los huérfanos
  /// (sessions/messages/executions sin FK) y sugiere limpiar conversaciones
  /// antes. Sólo tras confirmar despacha el borrado.
  Future<void> _confirmDelete(BuildContext context, Bot bot) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Eliminar este bot?',
      message:
          'Se borrará "${bot.name}" de forma permanente. Sus conversaciones, '
          'mensajes y ejecuciones quedarán huérfanos; si quieres limpiarlos, '
          'usa "Borrar conversaciones" en Mantenimiento antes de eliminar. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmKey: const Key('bot_detail.delete_confirm'),
    );
    if (!confirmed || !context.mounted) return;
    context.read<BotDetailBloc>().add(const BotDetailDeleteRequested());
  }

  // Duplicado intencional con BotsListPage._BotTile._channelLabel: regla
  // de 3 — al tercer consumidor extraer a un helper compartido en
  // `core/bots/` o similar (hoy son dos lugares).
  static String _channelLabel(BotChannel c) => switch (c) {
    BotChannel.waUnofficial => 'WhatsApp',
    BotChannel.waba => 'WhatsApp Business',
  };

  // Copy inline de un fallo de mutación. El 409 (conflicto de versión) ya
  // disparó un re-GET en el bloc: el snapshot está fresco, sólo falta avisar
  // y que el operador reintente.
  static String _failureMessage(BotsFailure f) => switch (f) {
    BotsConflictFailure() =>
      'Tu edición estaba desactualizada; la refrescamos. Revisa y reintenta.',
    BotsInvalidCreateFailure() =>
      'Revisa los datos del bot: el cambio no es válido.',
    BotsForbiddenFailure() => 'Tu rol no permite editar este bot.',
    BotsNotFoundFailure() => 'Este bot ya no existe en tu organización.',
    BotsNetworkFailure() ||
    BotsTimeoutFailure() => 'Sin conexión. Revisa tu red e inténtalo de nuevo.',
    BotsNotPausedFailure() ||
    BotsPairingNotStartedFailure() ||
    BotsPhoneRejectedFailure() ||
    BotsServerFailure() ||
    UnknownBotsFailure() => 'No pudimos guardar el cambio. Inténtalo de nuevo.',
  };
}

/// Launcher de las áreas del bot: una card con filas hacia las páginas
/// dedicadas, como en el hub de plantillas. Conversaciones y etiquetas WA
/// son operación diaria (todos los roles); variables y mantenimiento son
/// configuración ADMIN+ — el gateo espeja el `_redirect` del router.
class _SectionLauncher extends StatelessWidget {
  const _SectionLauncher({required this.bot, required this.isAdmin});

  final Bot bot;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('bot_detail.card.sections'),
      child: Column(
        children: <Widget>[
          AppSectionLink(
            rowKey: const Key('bot_detail.link.sessions'),
            icon: Icons.chat_outlined,
            title: 'Conversaciones',
            caption: 'La bandeja de chats del bot',
            onTap: () => context.push('/bots/${bot.id}/sessions'),
          ),
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
          AppSectionLink(
            rowKey: const Key('bot_detail.link.wa_labels'),
            icon: Icons.label_outline,
            title: 'Etiquetas de WhatsApp',
            caption: 'Catálogo del número y mapeo a flujos',
            onTap: () => context.push('/bots/${bot.id}/wa-labels'),
          ),
          if (isAdmin) ...<Widget>[
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            AppSectionLink(
              rowKey: const Key('bot_detail.link.variables'),
              icon: Icons.data_object,
              title: 'Variables',
              caption: 'Valores propios de este bot',
              onTap: () => context.push('/bots/${bot.id}/variables'),
            ),
            const Divider(height: AppTokens.sp5, color: AppTokens.divider),
            AppSectionLink(
              rowKey: const Key('bot_detail.link.maintenance'),
              icon: Icons.build_outlined,
              title: 'Mantenimiento',
              caption: 'Limpieza y reinicio de sesiones',
              onTap: () => context.push('/bots/${bot.id}/maintenance'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is BotsNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return _BackScaffold(
      child: Center(
        key: isNotFound
            ? const Key('bot_detail.error.not_found')
            : const Key('bot_detail.error.generic'),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                isNotFound
                    ? 'Este bot ya no existe en tu organización'
                    : 'No pudimos cargar el detalle del bot',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () => context.read<BotDetailBloc>().add(
                  const BotDetailLoadRequested(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
