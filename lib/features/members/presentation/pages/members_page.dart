import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../domain/entities/member.dart';
import '../bloc/members_bloc.dart';
import '../widgets/member_tile.dart';

/// Listado de miembros de la org activa (`GET /workspace/members`). Página
/// content-only: la ruta `/members` aporta Scaffold + AppBar.
///
/// De solo lectura: render del roster con rol y estado de verificación. El gate
/// de acceso es cosmético (tile admin-gated en Settings); la autoridad real es
/// el 403 del backend, por eso un fallo se muestra con un reintento genérico
/// sin discriminar el status crudo.
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MembersBloc, MembersState>(
      builder: (context, state) => switch (state) {
        MembersInitial() || MembersLoading() => const _LoadingView(),
        MembersLoaded(items: final items) => _LoadedView(items: items),
        MembersFailed() => const _FailedView(),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<Member> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyView();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4 + context.safeBottomInset,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
      itemBuilder: (context, i) => MemberTile(member: items[i]),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('members.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Text(
          'Esta organización no tiene miembros',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('members.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar los miembros',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () =>
                  context.read<MembersBloc>().add(const MembersLoadRequested()),
            ),
          ],
        ),
      ),
    );
  }
}
