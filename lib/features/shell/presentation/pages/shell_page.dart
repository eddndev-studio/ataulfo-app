import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/widgets/app_icon_pop.dart';
import '../../../bots/presentation/pages/bots_list_page.dart';
import '../../../bots/presentation/widgets/bot_create_sheet.dart';
import '../../../calendar/presentation/bloc/agenda_cubit.dart';
import '../../../calendar/presentation/pages/agenda_page.dart';
import '../../../labels/presentation/pages/labels_admin_page.dart';
import '../../../labels/presentation/widgets/label_edit_sheet.dart';
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
  const ShellPage({super.key, this.routeObserver, this.assistantDraft = ''});

  /// Observer compartido con el GoRouter del AppRouter. ShellPage no lo
  /// usa directamente: se lo entrega a Bots/TemplatesListPage para que
  /// se suscriban y dispatchen su refresh tras pop. `null` ⇒ los list
  /// pages siguen funcionando, sólo sin auto-refresh — útil en tests
  /// aislados que no necesitan el cableado completo.
  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  /// Handoff contextual desde una superficie del producto (p. ej. una
  /// plantilla). Se siembra en el composer del agente único; nunca se envía
  /// automáticamente para que el operador conserve control.
  final String assistantDraft;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late int _index;

  /// Índice de la tab Ajustes: destino del avatar de los headers de sección.
  static const int _settingsIndex = 5;

  @override
  void initState() {
    super.initState();
    // Conserva Bots como landing habitual, pero un handoff contextual abre el
    // primer tab (Asistente) de inmediato.
    _index = widget.assistantDraft.trim().isEmpty ? 1 : 0;
  }

  /// Punto ÚNICO de verdad de las tabs: por entrada viven juntos la etiqueta
  /// e ícono del navegador, la página del IndexedStack y el FAB contextual.
  /// Late + final: la lista se construye una sola vez al primer build (las
  /// páginas conservan su identidad de widget entre rebuilds, y con ella el
  /// IndexedStack su estado); no puede ser const porque Bots/Templates
  /// reciben el routeObserver del widget.
  late final List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(
      label: 'Asistente',
      icon: Icons.auto_awesome,
      page: PlatformAgentPage(initialDraft: widget.assistantDraft),
      lazy: true,
    ),
    _TabSpec(
      label: 'Bots',
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy,
      page: BotsListPage(
        routeObserver: widget.routeObserver,
        onOpenSettings: () => _select(_settingsIndex),
      ),
      fab: _botCreateFab,
    ),
    _TabSpec(
      label: 'Plantillas',
      icon: Icons.description_outlined,
      activeIcon: Icons.description,
      page: TemplatesListPage(
        routeObserver: widget.routeObserver,
        onOpenSettings: () => _select(_settingsIndex),
      ),
      fab: _templateCreateFab,
    ),
    _TabSpec(
      label: 'Etiquetas',
      icon: Icons.label_outline,
      activeIcon: Icons.label,
      page: LabelsAdminPage(onOpenSettings: () => _select(_settingsIndex)),
      fab: _labelCreateFab,
    ),
    // Agenda: lazy como el asistente (su cubit carga el día al abrir la tab,
    // sin coste en el arranque). Su FAB abre la reserva manual; al crear con
    // éxito la agenda recarga.
    _TabSpec(
      label: 'Agenda',
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      page: AgendaPage(onOpenSettings: () => _select(_settingsIndex)),
      fab: _agendaBookFab,
      lazy: true,
    ),
    // Ajustes cierra la barra: es la tab de menor frecuencia y el rincón
    // final es donde el pulgar la busca en el resto de apps. Su índice es
    // contrato de los onOpenSettings de los headers (_settingsIndex).
    const _TabSpec(
      label: 'Ajustes',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      page: SettingsPage(),
    ),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
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
            index: _index,
            children: <Widget>[
              for (var i = 0; i < _tabs.length; i++)
                if (_tabs[i].lazy && i != _index)
                  const SizedBox.shrink()
                else
                  _tabs[i].page,
            ],
          ),
        );
        // Sin AppBar del shell: cada tab trae su propio encabezado. Las
        // secciones montan la tarjeta-header full-bleed del kit; el asistente
        // (una superficie de chat con el hilo + composer fijos) trae chrome
        // compacto tipo app bar, porque un header alto y fijo le restaría
        // altura al hilo con el teclado abierto y sus acciones con estado no
        // leerían sobre el gradiente.
        return Scaffold(
          body: useRail
              ? Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: _select,
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        for (final t in _tabs)
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
          floatingActionButton: _tabs[_index].fab?.call(context),
          bottomNavigationBar: useRail
              ? null
              : BottomNavigationBar(
                  currentIndex: _index,
                  onTap: _select,
                  items: <BottomNavigationBarItem>[
                    for (final t in _tabs)
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

/// Una tab del shell: etiqueta + ícono del navegador (con su variante filled
/// para el estado activo), la página que monta el IndexedStack, su FAB
/// contextual (null ⇒ la tab no crea nada) y si la página se materializa
/// solo con la tab activa.
class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.page,
    this.fab,
    this.lazy = false,
  });

  final String label;
  final IconData icon;

  /// Variante filled del glifo para la tab activa. Nulo ⇒ el glifo no tiene
  /// par outlined/filled y la selección repite [icon].
  final IconData? activeIcon;

  IconData get selectedIcon => activeIcon ?? icon;

  final Widget page;
  final Widget Function(BuildContext context)? fab;
  final bool lazy;
}

// FABs por tab. Bots y Plantillas abren su hoja de creación (bottom sheet)
// in situ sobre el shell; al crear con éxito la hoja devuelve la entidad y
// aquí se empuja su detalle. No navegan a una pantalla intermedia: el back
// físico cierra la hoja sin salir del listado. La tab Etiquetas abre su
// propia hoja de creación.

Widget _botCreateFab(BuildContext context) => FloatingActionButton(
  key: const Key('shell.fab.bot_create'),
  onPressed: () async {
    final bot = await BotCreateSheet.open(context);
    if (bot != null && context.mounted) {
      unawaited(context.push('/bots/${bot.id}'));
    }
  },
  tooltip: 'Crear bot',
  child: const Icon(Icons.add),
);

Widget _templateCreateFab(BuildContext context) => FloatingActionButton(
  key: const Key('shell.fab.template_create'),
  onPressed: () async {
    final template = await TemplateCreateSheet.open(context);
    if (template != null && context.mounted) {
      unawaited(context.push('/templates/${template.id}'));
    }
  },
  tooltip: 'Crear plantilla',
  child: const Icon(Icons.add),
);

Widget _labelCreateFab(BuildContext context) => FloatingActionButton(
  key: const Key('shell.fab.label_create'),
  onPressed: () => LabelEditSheet.openCreate(context),
  tooltip: 'Crear etiqueta',
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
