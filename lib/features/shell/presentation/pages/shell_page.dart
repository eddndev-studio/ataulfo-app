import 'package:flutter/material.dart';

import '../../../bots/presentation/pages/bots_list_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

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
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(label: 'Bots', icon: Icons.smart_toy_outlined),
    _TabSpec(label: 'Ajustes', icon: Icons.settings_outlined),
  ];

  static const List<Widget> _bodies = <Widget>[BotsListPage(), SettingsPage()];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        // IndexedStack preserva el estado interno de cada tab (scroll
        // de la lista, bloc compartido por el shell) entre cambios.
        final body = IndexedStack(index: _index, children: _bodies);
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
