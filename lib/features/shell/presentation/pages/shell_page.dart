import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../bots/presentation/pages/bots_list_page.dart';
import '../../../bots/presentation/widgets/bot_create_sheet.dart';
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
  const ShellPage({super.key, this.routeObserver});

  /// Observer compartido con el GoRouter del AppRouter. ShellPage no lo
  /// usa directamente: se lo entrega a Bots/TemplatesListPage para que
  /// se suscriban y dispatchen su refresh tras pop. `null` ⇒ los list
  /// pages siguen funcionando, sólo sin auto-refresh — útil en tests
  /// aislados que no necesitan el cableado completo.
  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  /// Índice de la tab Ajustes: destino del avatar de los headers de sección.
  static const int _settingsIndex = 4;

  /// Punto ÚNICO de verdad de las tabs: por entrada viven juntos la etiqueta
  /// e ícono del navegador, la página del IndexedStack y el FAB contextual.
  /// Late + final: la lista se construye una sola vez al primer build (las
  /// páginas conservan su identidad de widget entre rebuilds, y con ella el
  /// IndexedStack su estado); no puede ser const porque Bots/Templates
  /// reciben el routeObserver del widget.
  late final List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(
      label: 'Bots',
      icon: Icons.smart_toy_outlined,
      page: BotsListPage(
        routeObserver: widget.routeObserver,
        onOpenSettings: () => _select(_settingsIndex),
      ),
      fab: _botCreateFab,
    ),
    _TabSpec(
      label: 'Plantillas',
      icon: Icons.description_outlined,
      page: TemplatesListPage(
        routeObserver: widget.routeObserver,
        onOpenSettings: () => _select(_settingsIndex),
      ),
      fab: _templateCreateFab,
    ),
    _TabSpec(
      label: 'Etiquetas',
      icon: Icons.label_outline,
      page: LabelsAdminPage(onOpenSettings: () => _select(_settingsIndex)),
      fab: _labelCreateFab,
    ),
    // El asistente es lazy: su chat (que lee PlatformAgentChatBloc y
    // muestra un spinner mientras carga) no debe vivir offstage en el
    // IndexedStack — evita el spinner oculto que colgaría pumpAndSettle y
    // difiere la carga hasta abrir la tab.
    const _TabSpec(
      label: 'Asistente',
      icon: Icons.auto_awesome,
      page: PlatformAgentPage(),
      lazy: true,
    ),
    // Ajustes cierra la barra: es la tab de menor frecuencia y el rincón
    // final es donde el pulgar la busca en el resto de apps. Su índice es
    // contrato de los onOpenSettings de los headers (_settingsIndex).
    const _TabSpec(
      label: 'Ajustes',
      icon: Icons.settings_outlined,
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
                        label: t.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Una tab del shell: etiqueta + ícono del navegador, la página que monta el
/// IndexedStack, su FAB contextual (null ⇒ la tab no crea nada) y si la
/// página se materializa solo con la tab activa.
class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.icon,
    required this.page,
    this.fab,
    this.lazy = false,
  });

  final String label;
  final IconData icon;
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
