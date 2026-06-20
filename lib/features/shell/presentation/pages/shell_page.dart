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

  // El asistente va de último para no recorrer los índices existentes
  // (Ajustes sigue en 3, que es a donde apuntan los onOpenSettings).
  static const int _assistantIndex = 4;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(label: 'Bots', icon: Icons.smart_toy_outlined),
    _TabSpec(label: 'Plantillas', icon: Icons.description_outlined),
    _TabSpec(label: 'Etiquetas', icon: Icons.label_outline),
    _TabSpec(label: 'Ajustes', icon: Icons.settings_outlined),
    _TabSpec(label: 'Asistente', icon: Icons.auto_awesome),
  ];

  // Los bodies ya no son `static const` porque BotsListPage/TemplatesListPage
  // reciben el routeObserver del widget. Late + final mantiene el mismo
  // requisito de "se construye una sola vez al primer build".
  late final List<Widget> _bodies = <Widget>[
    BotsListPage(
      routeObserver: widget.routeObserver,
      onOpenSettings: () => _select(3),
    ),
    TemplatesListPage(
      routeObserver: widget.routeObserver,
      onOpenSettings: () => _select(3),
    ),
    LabelsAdminPage(onOpenSettings: () => _select(3)),
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
        // La pestaña del asistente se materializa SOLO cuando está activa: así
        // su chat (que lee PlatformAgentChatBloc y muestra un spinner mientras
        // carga) no vive offstage en el IndexedStack — evita el spinner oculto
        // que colgaría pumpAndSettle y difiere la carga hasta abrir la tab.
        final body = Column(
          children: <Widget>[
            const EmailVerificationBanner(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: <Widget>[
                  ..._bodies,
                  _index == _assistantIndex
                      ? const PlatformAgentPage()
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        );
        // Sin AppBar del shell: TODAS las tabs traen header rico propio
        // (la tarjeta-header full-bleed ES su encabezado).
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

/// FAB por tab. Bots y Plantillas abren su hoja de creación (bottom sheet)
/// in situ sobre el shell; al crear con éxito la hoja devuelve la entidad y
/// aquí se empuja su detalle. No navegan a una pantalla intermedia: el back
/// físico cierra la hoja sin salir del listado. La tab Etiquetas abre su
/// propia hoja de creación.
Widget? _fab(BuildContext context, int index) => switch (index) {
  0 => FloatingActionButton(
    key: const Key('shell.fab.bot_create'),
    onPressed: () async {
      final bot = await BotCreateSheet.open(context);
      if (bot != null && context.mounted) {
        unawaited(context.push('/bots/${bot.id}'));
      }
    },
    tooltip: 'Crear bot',
    child: const Icon(Icons.add),
  ),
  1 => FloatingActionButton(
    key: const Key('shell.fab.template_create'),
    onPressed: () async {
      final template = await TemplateCreateSheet.open(context);
      if (template != null && context.mounted) {
        unawaited(context.push('/templates/${template.id}'));
      }
    },
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
