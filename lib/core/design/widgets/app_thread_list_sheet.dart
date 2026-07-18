import 'package:flutter/material.dart';

import '../safe_bottom.dart';
import '../tokens.dart';

/// Un hilo en el selector de conversaciones: id + título ya resuelto (el
/// llamador aplica el fallback de "sin título" al mapear su conversación).
class AppThreadListItem {
  const AppThreadListItem({
    required this.id,
    required this.title,
    this.subtitle = '',
  });

  final String id;
  final String title;
  final String subtitle;
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
class AppThreadListSheet extends StatefulWidget {
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

  @override
  State<AppThreadListSheet> createState() => _AppThreadListSheetState();
}

class _AppThreadListSheetState extends State<AppThreadListSheet> {
  final TextEditingController _search = TextEditingController();

  bool get _hasMenu => widget.onRename != null || widget.onDelete != null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.sp5,
                AppTokens.sp1,
                AppTokens.sp5,
                AppTokens.sp2,
              ),
              child: Text(widget.title!, style: textTheme.titleMedium),
            ),
          if (widget.items.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.sp4,
                0,
                AppTokens.sp4,
                AppTokens.sp2,
              ),
              child: TextField(
                key: Key('${widget.keyPrefix}.search'),
                controller: _search,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Buscar conversación',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          Flexible(
            child: Builder(
              builder: (context) {
                final query = _search.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? widget.items
                    : widget.items
                          .where(
                            (item) =>
                                item.title.toLowerCase().contains(query) ||
                                item.subtitle.toLowerCase().contains(query),
                          )
                          .toList(growable: false);
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppTokens.sp6),
                    child: Center(
                      child: Text(
                        'No hay conversaciones que coincidan.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  key: Key('${widget.keyPrefix}.list'),
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: context.sheetBottomInset),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ThreadTile(
                    keyPrefix: widget.keyPrefix,
                    item: filtered[i],
                    active: filtered[i].id == widget.activeId,
                    onSelect: widget.onSelect,
                    onRename: widget.onRename,
                    onDelete: widget.onDelete,
                    hasMenu: _hasMenu,
                  ),
                );
              },
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
      subtitle: item.subtitle.isEmpty
          ? null
          : Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
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
