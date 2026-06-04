import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../bots/presentation/pages/bots_list_page.dart';
import '../../../labels/presentation/pages/labels_admin_page.dart';
import '../../../labels/presentation/widgets/label_edit_sheet.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../templates/presentation/pages/templates_list_page.dart';
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

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(label: 'Bots', icon: Icons.smart_toy_outlined),
    _TabSpec(label: 'Plantillas', icon: Icons.description_outlined),
    _TabSpec(label: 'Etiquetas', icon: Icons.label_outline),
    _TabSpec(label: 'Ajustes', icon: Icons.settings_outlined),
  ];

  // Los bodies ya no son `static const` porque BotsListPage/TemplatesListPage
  // reciben el routeObserver del widget. Late + final mantiene el mismo
  // requisito de "se construye una sola vez al primer build".
  late final List<Widget> _bodies = <Widget>[
    BotsListPage(routeObserver: widget.routeObserver),
    TemplatesListPage(routeObserver: widget.routeObserver),
    const LabelsAdminPage(),
    const SettingsPage(),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        // IndexedStack preserva el estado interno de cada tab (scroll
        // de la lista, bloc compartido por el shell) entre cambios. El aviso
        // de verificación se apila ENCIMA del contenido de las tabs (sólo se
        // pinta a sí mismo cuando el correo no está verificado), idéntico en
        // ambos layouts (compact y rail).
        final body = Column(
          children: <Widget>[
            const EmailVerificationBanner(),
            Expanded(child: IndexedStack(index: _index, children: _bodies)),
          ],
        );
        return Scaffold(
          appBar: AppBar(title: Text(_tabs[_index].label)),
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
          floatingActionButton: _fab(context, _index),
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

class _TabSpec {
  const _TabSpec({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// FAB por tab. La tab Bots arranca el flujo "crear bot" abriendo el
/// selector de plantilla; la tab Plantillas arranca el formulario de
/// creación. Ambos usan push (no go) para preservar el shell debajo de
/// la pila: el back físico cancela la operación y vuelve al listado. La
/// tab Etiquetas abre la hoja de creación in situ (modal sobre el shell,
/// sin navegar): el catálogo se gestiona dentro de la propia tab.
Widget? _fab(BuildContext context, int index) => switch (index) {
  0 => FloatingActionButton(
    key: const Key('shell.fab.bot_template_picker'),
    onPressed: () => context.push('/bots/new'),
    tooltip: 'Crear bot',
    child: const Icon(Icons.add),
  ),
  1 => FloatingActionButton(
    key: const Key('shell.fab.template_create'),
    onPressed: () => context.push('/templates/new'),
    tooltip: 'Crear plantilla',
    child: const Icon(Icons.add),
  ),
  2 => FloatingActionButton(
    key: const Key('shell.fab.label_create'),
    onPressed: () => LabelEditSheet.openCreate(context),
    tooltip: 'Crear etiqueta',
    child: const Icon(Icons.add),
  ),
  _ => null,
};
