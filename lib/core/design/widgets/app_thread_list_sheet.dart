import 'package:flutter/material.dart';

import '../safe_bottom.dart';
import '../tokens.dart';

/// Un hilo en el selector de conversaciones: id + título ya resuelto (el
/// llamador aplica el fallback de "sin título" al mapear su conversación).
class AppThreadListItem {
  const AppThreadListItem({required this.id, required this.title});

  final String id;
  final String title;
}

/// Selector de hilos compartido por las superficies de chat con agentes: una
/// lista con el hilo activo marcado. Tocar un hilo lo selecciona (el llamador
/// cierra el cajón); un menú (⋮) opcional por hilo ofrece Renombrar/Eliminar
/// cuando la superficie lo soporta —el entrenador, que hoy no expone esas
/// operaciones, lo omite pasando ambos callbacks en null—.
///
/// Es presentacional: no abre ni cierra el modal ni conoce blocs. El llamador
/// lo monta como contenido de un `showAppBottomSheet` y cablea los callbacks a
/// sus eventos. [keyPrefix] namespacia las keys (`<prefix>.list`,
/// `<prefix>.item.<id>`, `<prefix>.menu.<id>`) para que cada superficie
/// conserve las suyas.
class AppThreadListSheet extends StatelessWidget {
  const AppThreadListSheet({
    super.key,
    required this.keyPrefix,
    required this.items,
    required this.activeId,
    required this.onSelect,
    this.title,
    this.onRename,
    this.onDelete,
  });

  final String keyPrefix;
  final List<AppThreadListItem> items;
  final String activeId;
  final ValueChanged<String> onSelect;
  final String? title;

  /// Renombrar/Eliminar un hilo. Ambos null ⇒ sin menú (selección solamente).
  final ValueChanged<String>? onRename;
  final ValueChanged<String>? onDelete;

  bool get _hasMenu => onRename != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.sp5,
                AppTokens.sp1,
                AppTokens.sp5,
                AppTokens.sp2,
              ),
              child: Text(title!, style: textTheme.titleMedium),
            ),
          Flexible(
            child: ListView.builder(
              key: Key('$keyPrefix.list'),
              shrinkWrap: true,
              padding: EdgeInsets.only(bottom: context.sheetBottomInset),
              itemCount: items.length,
              itemBuilder: (context, i) => _ThreadTile(
                keyPrefix: keyPrefix,
                item: items[i],
                active: items[i].id == activeId,
                onSelect: onSelect,
                onRename: onRename,
                onDelete: onDelete,
                hasMenu: _hasMenu,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.keyPrefix,
    required this.item,
    required this.active,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    required this.hasMenu,
  });

  final String keyPrefix;
  final AppThreadListItem item;
  final bool active;
  final ValueChanged<String> onSelect;
  final ValueChanged<String>? onRename;
  final ValueChanged<String>? onDelete;
  final bool hasMenu;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('$keyPrefix.item.${item.id}'),
      selected: active,
      leading: Icon(
        active ? Icons.radio_button_checked : Icons.chat_bubble_outline,
        color: active ? AppTokens.primary : AppTokens.text2,
      ),
      title: Text(
        item.title,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: active ? AppTokens.primary : AppTokens.text1,
        ),
      ),
      trailing: hasMenu
          ? PopupMenuButton<String>(
              key: Key('$keyPrefix.menu.${item.id}'),
              icon: const Icon(Icons.more_vert, color: AppTokens.text2),
              onSelected: (action) {
                if (action == 'rename') {
                  onRename?.call(item.id);
                } else if (action == 'delete') {
                  onDelete?.call(item.id);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                if (onRename != null)
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Renombrar'),
                  ),
                if (onDelete != null)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Eliminar'),
                  ),
              ],
            )
          : null,
      onTap: () => onSelect(item.id),
    );
  }
}
