import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../invitations/presentation/pages/invitations_page.dart';
import '../../../members/presentation/pages/members_page.dart';

/// Superficie única de equipo y acceso.
///
/// Miembros e invitaciones comparten ruta y providers; cambiar de pestaña no
/// vuelve a cargar ni apila pantallas equivalentes. [initialTab] mantiene los
/// deep links históricos de `/members` y `/invitations`.
class OrganizationTeamPage extends StatefulWidget {
  const OrganizationTeamPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<OrganizationTeamPage> createState() => _OrganizationTeamPageState();
}

class _OrganizationTeamPageState extends State<OrganizationTeamPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          color: AppTokens.surface1,
          child: TabBar(
            controller: _controller,
            tabs: const <Tab>[
              Tab(text: 'Miembros'),
              Tab(text: 'Invitaciones'),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTokens.divider),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: <Widget>[
              MembersPage(onInvite: () => _controller.animateTo(1)),
              const InvitationsPage(),
            ],
          ),
        ),
      ],
    );
  }
}
