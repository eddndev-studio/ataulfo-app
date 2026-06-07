// Pesa >400 LOC porque agrupa el shell del listado de Bots (header, CTA de
// creación, buscador, filtros, tile, pills de estado y los estados vacío/
// carga/error) con sus helpers cohesivos. Los widgets viven solo aquí; un split
// compartiría estructuras privadas entre archivos hermanos sin reuso real. Si
// crece más, el primer corte es extraer _BotTile + _StatusPill a
// `widgets/bot_tile.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/bot.dart';
import '../bloc/bots_bloc.dart';

/// Filtro por estado del listado. Es estado de UI local (client-side sobre la
/// lista ya cargada), no del bloc: el backend devuelve todos los bots y el
/// operador acota la vista sin un round-trip.
enum _BotFilter { all, active, paused }

/// Listado de Bots (S04). Consume el BotsBloc del scope; el cableado del
/// provider lo hace el shell. Es content-only: el Scaffold, el AppBar y el FAB
/// "crear bot" los aporta el ShellPage (la card-CTA de esta page comparte ese
/// destino `/bots/new`).
///
/// Si recibe un `routeObserver`, se suscribe como `RouteAware` y dispara
/// `BotsRefreshRequested` cuando una sub-ruta (create/edit) vuelve al stack
/// tras un pop. Sin observer, la page funciona idéntico — composición opcional.
class BotsListPage extends StatefulWidget {
  const BotsListPage({super.key, this.routeObserver});

  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  @override
  State<BotsListPage> createState() => _BotsListPageState();
}

class _BotsListPageState extends State<BotsListPage> with RouteAware {
  late final TextEditingController _searchCtrl;
  _BotFilter _filter = _BotFilter.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    // Cada keystroke re-filtra la lista visible (client-side); un setState basta.
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = widget.routeObserver;
    if (observer == null) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) observer.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Sub-ruta encima del listado (e.g. /bots/new, /bots/:id) popeó y el
    // listado vuelve al foreground. Refetch transparente alinea el bloc con la
    // verdad del backend sin pull-to-refresh manual.
    context.read<BotsBloc>().add(const BotsRefreshRequested());
  }

  /// Aplica búsqueda (nombre o canal) + filtro de estado a la lista cargada.
  List<Bot> _applyFilters(List<Bot> items) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return items.where((b) {
      final matchesQuery =
          q.isEmpty ||
          b.name.toLowerCase().contains(q) ||
          _channelLabel(b.channel).toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        _BotFilter.all => true,
        _BotFilter.active => !b.paused,
        _BotFilter.paused => b.paused,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<BotsBloc>();
    bloc.add(const BotsRefreshRequested());
    // Espera a que el bloc deje el estado refreshing (o caiga a Failed) para
    // que el RefreshIndicator no quite el spinner antes de tiempo.
    await bloc.stream.firstWhere(
      (s) => (s is BotsLoaded && !s.isRefreshing) || s is BotsFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotsBloc, BotsState>(
      builder: (context, state) => switch (state) {
        BotsInitial() || BotsLoading() => const _LoadingView(),
        BotsLoaded(items: final items) =>
          items.isEmpty
              ? _EmptyView(onRefresh: () => _refresh(context))
              : _buildLoaded(context, items),
        BotsFailed() => const _FailedView(),
      },
    );
  }

  Widget _buildLoaded(BuildContext context, List<Bot> items) {
    final filtered = _applyFilters(items);
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTokens.sp5,
          AppTokens.sp5,
          AppTokens.sp5,
          AppTokens.sp5 + context.safeBottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _Header(),
            const SizedBox(height: AppTokens.sp5),
            _CreateBotCard(onTap: () => context.push('/bots/new')),
            const SizedBox(height: AppTokens.sp5),
            _SearchField(controller: _searchCtrl),
            const SizedBox(height: AppTokens.sp4),
            _FilterChips(
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: AppTokens.sp5),
            if (filtered.isEmpty)
              const _NoResults()
            else
              for (final bot in filtered) ...<Widget>[
                _BotTile(bot: bot),
                const SizedBox(height: AppTokens.cardGap),
              ],
          ],
        ),
      ),
    );
  }
}

/// Lead descriptivo de la pantalla. El AppBar del shell ya titula "Bots", así
/// que aquí NO se repite el título (evita la redundancia de interfaz): solo el
/// texto que explica la sección.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      'Configura agentes para automatizar conversaciones, tareas y flujos.',
      key: const Key('bots.header'),
      style: textTheme.bodyLarge?.copyWith(color: AppTokens.text2),
    );
  }
}

/// CTA principal de la pantalla: la única card con gradiente de marca. Toda la
/// card es UN botón tappable → `/bots/new` (mismo destino que el FAB del shell).
/// La estructura —ícono-botón a la izquierda, título + descripción al centro,
/// chevron a la derecha— hace que se lea como un botón pleno, no como una card
/// con una pastilla de acción suelta dentro.
class _CreateBotCard extends StatelessWidget {
  const _CreateBotCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard.gradient(
      key: const Key('bots.create_cta'),
      onTap: onTap,
      // padding 0: el padding real lo pone la fila; la marca de agua debe poder
      // sangrar hasta los bordes de la card antes del recorte.
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Stack(
          children: <Widget>[
            // Marca de agua: glifo grande anclado a la derecha, escalado al alto
            // de la card y recortado por el borde, a baja opacidad sobre el
            // gradiente. Decorativo ⇒ excluido del árbol semántico. (Cuando
            // exista una ilustración de marca propia, reemplaza a este ícono.)
            Positioned(
              top: 0,
              bottom: 0,
              right: -28,
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: Icon(
                    Icons.smart_toy,
                    color: AppTokens.onPrimary.withValues(alpha: 0.14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTokens.cardPadding),
              child: Row(
                children: <Widget>[
                  const _CtaIconButton(),
                  const SizedBox(width: AppTokens.sp4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Nuevo bot',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppTokens.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTokens.sp1),
                        Text(
                          'Crea un bot desde cero y define su comportamiento.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTokens.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.sp3),
                  const Icon(Icons.chevron_right, color: AppTokens.onPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícono-botón cuadrado de la card-CTA: cuadrado oscuro (`onPrimary`) con un
/// "+" en ámbar. Es el ancla visual que comunica "toda la card es un botón".
/// Decorativo (la card ya porta la semántica de acción).
class _CtaIconButton extends StatelessWidget {
  const _CtaIconButton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTokens.onPrimary,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: const Icon(Icons.add, color: AppTokens.primary, size: 26),
      ),
    );
  }
}

/// Buscador del listado: filtra por nombre o canal (client-side). El proveedor
/// no se busca porque no vive en el Bot (está en la Template).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      key: const Key('bots.search'),
      label: 'Buscar bot',
      hint: 'Nombre o canal',
      controller: controller,
    );
  }
}

/// Fila de filtros por estado. Selección única — al tocar un chip se fija ese
/// filtro (ignora el bool de `onSelected`).
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _BotFilter selected;
  final ValueChanged<_BotFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.sp2,
      runSpacing: AppTokens.sp2,
      children: <Widget>[
        _chip('Todos', _BotFilter.all, 'all'),
        _chip('Activos', _BotFilter.active, 'active'),
        _chip('Pausados', _BotFilter.paused, 'paused'),
      ],
    );
  }

  Widget _chip(String label, _BotFilter value, String id) => AppChoiceChip(
    key: Key('bots.filter.$id'),
    label: label,
    selected: selected == value,
    onSelected: (_) => onSelected(value),
  );
}

/// Card tappable de un bot. Glifo de entidad + nombre + canal + pill de estado.
/// Sin sombra; la jerarquía la da `surface2` + padding + separación.
class _BotTile extends StatelessWidget {
  const _BotTile({required this.bot});

  final Bot bot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = bot.identifier == null || bot.identifier!.trim().isEmpty
        ? _channelLabel(bot.channel)
        : '${_channelLabel(bot.channel)} · ${bot.identifier!.trim()}';
    return AppCard(
      key: Key('bots.tile.${bot.id}'),
      // push (no go): el detalle se apila sobre el listado para que el back
      // físico y la flecha del AppBar vuelvan al shell con la tab Bots activa.
      onTap: () => context.push('/bots/${bot.id}'),
      child: Row(
        children: <Widget>[
          const AppEntityIcon(icon: Icons.smart_toy_outlined),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(bot.name, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          _StatusPill(paused: bot.paused),
        ],
      ),
    );
  }
}

/// Pill de estado discreta (no compite con el nombre). Activo → neutral con dot
/// `accent`; pausado → outline con dot neutro. No se usa fill primary ni
/// `success`: el dot cálido basta para comunicar "encendido".
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (paused) {
      return const AppPill.outline(label: 'Pausado', dot: AppPillDot.paused);
    }
    return const AppPill.neutral(label: 'Activo', dot: AppPillDot.active);
  }
}

/// La búsqueda/filtro no dejó bots visibles (pero sí los hay en la org).
class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('bots.no_results'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp6),
      child: Center(
        child: Text(
          'Ningún bot coincide con tu búsqueda o filtro.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
          const SizedBox(height: AppTokens.sp3),
          Text(
            'Cargando bots…',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío (cero bots): card glass centrada que ES el CTA de creación.
/// Scrollable para conservar el pull-to-refresh sobre el vacío.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.sp5),
              child: Center(
                child: AppCard.glass(
                  key: const Key('bots.empty'),
                  padding: const EdgeInsets.all(AppTokens.cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const AppEntityIcon(
                        icon: Icons.smart_toy_outlined,
                        size: 56,
                        highlighted: true,
                      ),
                      const SizedBox(height: AppTokens.sp4),
                      Text(
                        'Aún no tienes bots',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.sp2),
                      Text(
                        'Crea tu primer bot para automatizar una conversación '
                        'o tarea recurrente.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTokens.text2,
                        ),
                      ),
                      const SizedBox(height: AppTokens.sp5),
                      AppButton.filled(
                        label: 'Crear bot',
                        icon: Icons.add,
                        fullWidth: true,
                        onPressed: () => context.push('/bots/new'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado de error de carga: card con mensaje + reintento (no toda roja).
class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppCard(
          key: const Key('bots.error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No se pudieron cargar los bots',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.sp2),
              Text(
                'Revisa tu conexión o intenta nuevamente.',
                style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
              const SizedBox(height: AppTokens.sp4),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () =>
                    context.read<BotsBloc>().add(const BotsLoadRequested()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _channelLabel(BotChannel c) => switch (c) {
  BotChannel.waUnofficial => 'WhatsApp',
  BotChannel.waba => 'WhatsApp Business',
};
