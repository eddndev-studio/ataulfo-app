import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/role_privilege.dart';
import '../../../../core/design/widgets/app_icon_pop.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../calendar/presentation/bloc/agenda_cubit.dart';
import '../../../calendar/presentation/pages/agenda_page.dart';
import '../../../conversations/presentation/bloc/conversations_bloc.dart';
import '../../../conversations/presentation/pages/conversations_list_page.dart';
import '../../../labels/presentation/bloc/labels_admin_bloc.dart';
import '../../../platform_agent/presentation/pages/platform_agent_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../templates/presentation/pages/templates_list_page.dart';
import '../../../templates/presentation/widgets/template_create_sheet.dart';
import '../widgets/email_verification_banner.dart';

/// Shell adaptable de la app autenticada. Hospeda los tabs del producto y
/// resuelve la navegación lateral según el ancho disponible (M3: compact
/// usa BottomNavigationBar; medium+/expanded usa NavigationRail).
///
/// Los tabs viven como widget state (`IndexedStack` + `_index`) — NO como
/// sub-rutas del GoRouter. Razón: el redirect global del router fue
/// estabilizado en slices previos sobre `/`/`login`/`/home`; meter
/// sub-rutas por tab obligaría a reabrir esa lógica sin ganar nada
/// (los tabs no son destinos compartibles por URL en este producto).
class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    this.routeObserver,
    this.assistantDraft = '',
    this.contextualBotId,
  });

  /// Observer compartido con el GoRouter del AppRouter. ShellPage no lo
  /// usa directamente: se lo entrega a TemplatesListPage para que
  /// se suscriban y dispatchen su refresh tras pop. `null` ⇒ los list
  /// pages siguen funcionando, sólo sin auto-refresh — útil en tests
  /// aislados que no necesitan el cableado completo.
  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  /// Handoff contextual desde una superficie del producto (p. ej. una
  /// plantilla). Se siembra en el composer del agente único; nunca se envía
  /// automáticamente para que el operador conserve control.
  final String assistantDraft;

  /// Conexión concreta solicitada por una entrada contextual histórica.
  /// Cambiarla actualiza el mismo bloc para no desmontar el resto del shell.
  final String? contextualBotId;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late _ShellTab _selectedTab;
  late final ValueNotifier<bool> _inboxVisible;

  @override
  void initState() {
    super.initState();
    // Bandeja es la landing operativa. El handoff sólo abre Ataúlfo si el rol
    // posee la capacidad global; nunca debe convertirse en una evasión para
    // un Agente limitado a sus Canales.
    final auth = context.read<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.identity.role : '';
    _selectedTab =
        widget.assistantDraft.trim().isNotEmpty && isSupervisorOrAbove(role)
        ? _ShellTab.platformAgent
        : _ShellTab.inbox;
    _inboxVisible = ValueNotifier<bool>(_selectedTab == _ShellTab.inbox);
  }

  @override
  void didUpdateWidget(covariant ShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextualBotId != widget.contextualBotId) {
      _selectedTab = _ShellTab.inbox;
      _inboxVisible.value = true;
      context.read<ConversationsBloc>().add(
        ConversationsChannelChanged(widget.contextualBotId),
      );
    }
  }

  @override
  void dispose() {
    _inboxVisible.dispose();
    super.dispose();
  }

  /// Punto ÚNICO de verdad de las tabs: por entrada viven juntos la etiqueta
  /// e ícono del navegador, la página del IndexedStack y el FAB contextual.
  /// Late + final: la lista se construye una sola vez al primer build (las
  /// páginas conservan su identidad de widget entre rebuilds, y con ella el
  /// IndexedStack su estado); no puede ser const porque Bots/Templates
  /// reciben el routeObserver del widget.
  late final List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(
      id: _ShellTab.inbox,
      label: 'Bandeja',
      icon: Icons.inbox_outlined,
      activeIcon: Icons.inbox,
      page: ConversationsListPage(
        onOpenSettings: () => _select(_ShellTab.settings),
        isActiveListenable: _inboxVisible,
      ),
    ),
    _TabSpec(
      id: _ShellTab.assistants,
      label: 'Asistentes',
      icon: Icons.support_agent_outlined,
      activeIcon: Icons.support_agent,
      page: TemplatesListPage(
        routeObserver: widget.routeObserver,
        onOpenSettings: () => _select(_ShellTab.settings),
      ),
      fab: _assistantCreateFab,
      adminOnly: true,
    ),
    // Agenda: lazy como el asistente (su cubit carga el día al abrir la tab,
    // sin coste en el arranque). Su FAB abre la reserva manual; al crear con
    // éxito la agenda recarga.
    _TabSpec(
      id: _ShellTab.agenda,
      label: 'Agenda',
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      page: AgendaPage(onOpenSettings: () => _select(_ShellTab.settings)),
      fab: _agendaBookFab,
      lazy: true,
      supervisorOnly: true,
    ),
    _TabSpec(
      id: _ShellTab.platformAgent,
      label: 'Ataúlfo',
      icon: Icons.auto_awesome,
      page: PlatformAgentPage(initialDraft: widget.assistantDraft),
      lazy: true,
      supervisorOnly: true,
    ),
    // Ajustes cierra la barra: es la tab de menor frecuencia y el rincón
    // final es donde el pulgar la busca en el resto de apps. Su índice es
    // contrato de los onOpenSettings de los headers (_settingsIndex).
    _TabSpec(
      id: _ShellTab.settings,
      label: 'Ajustes',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      page: SettingsPage(
        onLabelsChanged: () => context.read<LabelsAdminBloc>().add(
          const LabelsAdminRefreshRequested(),
        ),
      ),
    ),
  ];

  void _select(_ShellTab tab) {
    if (_selectedTab == tab) return;
    _inboxVisible.value = tab == _ShellTab.inbox;
    setState(() => _selectedTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.identity.role : '';
    final tabs = _tabs
        .where((tab) => tab.visibleFor(role))
        .toList(growable: false);
    final selectedIndex = tabs.indexWhere((tab) => tab.id == _selectedTab);
    // Si el rol cambió mientras el shell estaba vivo, caer cerradamente a la
    // Bandeja sin materializar ni un frame de la superficie ya revocada.
    final effectiveIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final effectiveTab = tabs[effectiveIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        // IndexedStack preserva el estado interno de cada tab (scroll
        // de la lista, bloc compartido por el shell) entre cambios. El aviso
        // de verificación envuelve el contenido de las tabs (sólo pinta su
        // franja cuando el correo no está verificado, y coordina el inset del
        // status bar), idéntico en ambos layouts (compact y rail).
        final body = EmailVerificationBanner(
          child: IndexedStack(
            index: effectiveIndex,
            children: <Widget>[
              for (var i = 0; i < tabs.length; i++)
                if (tabs[i].lazy && i != effectiveIndex)
                  const SizedBox.shrink()
                else
                  tabs[i].page,
            ],
          ),
        );
        // Sin AppBar del shell: cada tab trae su propio encabezado. Catálogos y
        // ajustes montan la tarjeta full-bleed del kit; Bandeja y Ataúlfo son
        // superficies operativas de mensajería y usan chrome compacto fijo para
        // no restar altura a listas/hilos ni separar sus acciones contextuales.
        return Scaffold(
          body: useRail
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: effectiveIndex,
                      onDestinationSelected: (i) => _select(tabs[i].id),
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        for (final t in tabs)
                          NavigationRailDestination(
                            icon: Icon(t.icon),
                            // La selección monta un widget nuevo: el pop del
                            // kit corre en cada activación de la tab.
                            selectedIcon: AppIconPop(icon: t.selectedIcon),
                            label: Text(t.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          floatingActionButton: effectiveTab.fab?.call(context),
          bottomNavigationBar: useRail
              ? null
              : BottomNavigationBar(
                  currentIndex: effectiveIndex,
                  onTap: (i) => _select(tabs[i].id),
                  items: <BottomNavigationBarItem>[
                    for (final t in tabs)
                      BottomNavigationBarItem(
                        icon: Icon(t.icon),
                        // Ídem rail: el activeIcon monta al seleccionarse y
                        // el pop del kit corre en cada activación.
                        activeIcon: AppIconPop(icon: t.selectedIcon),
                        label: t.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

enum _ShellTab { inbox, assistants, agenda, platformAgent, settings }

/// Una tab del shell: etiqueta + ícono del navegador (con su variante filled
/// para el estado activo), la página que monta el IndexedStack, su FAB
/// contextual (null ⇒ la tab no crea nada) y si la página se materializa
/// solo con la tab activa.
class _TabSpec {
  const _TabSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.page,
    this.fab,
    this.lazy = false,
    this.adminOnly = false,
    this.supervisorOnly = false,
  });

  final _ShellTab id;
  final String label;
  final IconData icon;

  /// Variante filled del glifo para la tab activa. Nulo ⇒ el glifo no tiene
  /// par outlined/filled y la selección repite [icon].
  final IconData? activeIcon;

  IconData get selectedIcon => activeIcon ?? icon;

  final Widget page;
  final Widget Function(BuildContext context)? fab;
  final bool lazy;
  final bool adminOnly;
  final bool supervisorOnly;

  bool visibleFor(String role) {
    if (adminOnly) return isAdminOrAbove(role);
    if (supervisorOnly) return isSupervisorOrAbove(role);
    return true;
  }
}

// FABs por tab. Asistentes abre su hoja de creación in situ; los Canales se
// conectan dentro del Asistente y Etiquetas se gestiona desde Ajustes.
Widget _assistantCreateFab(BuildContext context) => FloatingActionButton(
  key: const Key('shell.fab.template_create'),
  onPressed: () async {
    final template = await TemplateCreateSheet.open(context);
    if (template != null && context.mounted) {
      unawaited(context.push('/assistants/${template.id}'));
    }
  },
  tooltip: 'Crear Asistente',
  child: const Icon(Icons.add),
);

// La reserva manual vive en su propia pushed route: el back físico vuelve a la
// agenda sin salir de la app. Al crear con éxito la route hace pop(true) y aquí
// se recarga el día en foco para que la nueva cita aparezca.
Widget _agendaBookFab(BuildContext context) => FloatingActionButton(
  key: const Key('shell.fab.agenda_book'),
  onPressed: () async {
    final agenda = context.read<AgendaCubit>();
    final created = await context.push<bool>('/agenda/book');
    if (created == true) {
      await agenda.load();
    }
  },
  tooltip: 'Reservar cita',
  child: const Icon(Icons.add),
);
