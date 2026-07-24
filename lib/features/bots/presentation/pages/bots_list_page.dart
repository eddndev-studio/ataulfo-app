// Agrupa el shell del listado de Bots (header, CTA de creación, buscador,
// filtros y los estados vacío/carga/error) con sus helpers cohesivos. El tile y
// sus pills de estado viven aparte en `widgets/bot_tile.dart` porque los
// consume también su propio test de widget.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_empty_state.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../../../core/design/widgets/app_header_card.dart';
import '../../../../core/design/widgets/app_loading_indicator.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/util/user_greeting.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/bot.dart';
import '../bloc/bot_sessions_cubit.dart';
import '../bloc/bots_bloc.dart';
import '../widgets/bot_create_sheet.dart';
import '../widgets/bot_tile.dart';

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
  const BotsListPage({super.key, this.routeObserver, this.onOpenSettings});

  final RouteObserver<PageRoute<dynamic>>? routeObserver;

  /// Acción del avatar del header → abrir Ajustes. La aporta el shell (que
  /// controla los tabs). Sin ella, el avatar es no-op.
  final VoidCallback? onOpenSettings;

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
          channelLabel(b.channel).toLowerCase().contains(q);
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
    // Cada vez que el listado se asienta (carga inicial, pull-to-refresh o
    // vuelta de una sub-ruta), se re-consultan las sesiones de sus bots: el
    // dato de sesión no viene en `GET /bots` y se abanica aparte.
    return BlocListener<BotsBloc, BotsState>(
      listenWhen: (previous, current) =>
          current is BotsLoaded && !current.isRefreshing,
      listener: (context, state) {
        if (state is BotsLoaded) {
          context.read<BotSessionsCubit>().load(
            state.items.map((b) => b.id).toList(),
          );
        }
      },
      child: BlocBuilder<BotsBloc, BotsState>(
        builder: (context, state) => switch (state) {
          BotsInitial() || BotsLoading() => const _LoadingView(),
          BotsLoaded(items: final items) =>
            items.isEmpty
                ? _EmptyView(onRefresh: () => _refresh(context))
                : _buildLoaded(context, items),
          BotsFailed() => const _FailedView(),
        },
      ),
    );
  }

  String _emailFromSession(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    return switch (state) {
      AuthAuthenticated(:final identity) => identity.email,
      AuthAuthenticatedNoOrg(:final identity) => identity.email,
      _ => '',
    };
  }

  Widget _buildLoaded(BuildContext context, List<Bot> items) {
    final filtered = _applyFilters(items);
    final user = userGreeting(_emailFromSession(context));
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Sin padding aquí: el header es full-bleed y va pegado arriba. El
        // resto del contenido lleva su propio padding más abajo.
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppHeaderCard(
              greeting: user.greeting,
              // Mismo término que la etiqueta de la tab del shell: "Bots" es
              // el nombre interno consistente de la entidad en toda la app.
              title: 'Canales',
              avatarInitial: user.initial,
              onAvatarTap: widget.onOpenSettings ?? () {},
              watermark: Icons.smart_toy,
            ),
            Padding(
              key: const Key('bots.content_padding'),
              padding: EdgeInsets.fromLTRB(
                AppTokens.sp5,
                AppTokens.sp5,
                AppTokens.sp5,
                // fabClearance: la última fila debe poder quedar por encima
                // del FAB de crear que flota sobre esta tab.
                AppTokens.fabClearance + context.safeBottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
                    // El estado de sesión por bot lo aporta el cubit compañero;
                    // el tile lo pinta conforme llega (o lo omite si no hay dato).
                    BlocBuilder<BotSessionsCubit, BotSessionsState>(
                      builder: (context, sessions) =>
                          _BotsCard(bots: filtered, sessions: sessions),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El listado como UNA card que apila las filas de bots separadas por divider
/// hairline (idioma de los hubs y de ajustes), en lugar de una card suelta por
/// item.
class _BotsCard extends StatelessWidget {
  const _BotsCard({required this.bots, required this.sessions});

  final List<Bot> bots;
  final BotSessionsState sessions;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < bots.length; i++) {
      if (i > 0) {
        rows.add(
          const Divider(height: AppTokens.sp5, color: AppTokens.divider),
        );
      }
      rows.add(
        BotTile(bot: bots[i], sessionState: sessions.stateFor(bots[i].id)),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
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
    return AppSearchField(
      key: const Key('bots.search'),
      hint: 'Buscar canales por nombre o tipo…',
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
  Widget build(BuildContext context) =>
      const AppLoadingIndicator(label: 'Cargando Canales…');
}

/// Estado vacío (cero bots): card glass centrada que ES el CTA de creación.
/// Scrollable para conservar el pull-to-refresh sobre el vacío.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
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
                child: AppEmptyState(
                  key: const Key('bots.empty'),
                  icon: Icons.smart_toy_outlined,
                  title: 'Aún no tienes Canales',
                  description:
                      'Crea tu primer bot para automatizar una conversación '
                      'o tarea recurrente.',
                  ctaLabel: 'Crear bot',
                  ctaIcon: Icons.add,
                  onCta: () async {
                    final bot = await BotCreateSheet.open(context);
                    if (bot != null && context.mounted) {
                      unawaited(context.push('/bots/${bot.id}'));
                    }
                  },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp5),
        child: AppErrorState(
          key: const Key('bots.error'),
          message: 'No se pudieron cargar los Canales',
          description: 'Revisa tu conexión o intenta nuevamente.',
          onRetry: () =>
              context.read<BotsBloc>().add(const BotsLoadRequested()),
        ),
      ),
    );
  }
}
