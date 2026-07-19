import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_error_state.dart';
import '../../domain/failures/conversations_failure.dart';
import '../bloc/conversations_bloc.dart';

class InboxLoadingView extends StatelessWidget {
  const InboxLoadingView({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const NeverScrollableScrollPhysics(),
    slivers: <Widget>[
      SliverToBoxAdapter(child: header),
      const SliverPadding(
        padding: EdgeInsets.all(AppTokens.sp4),
        sliver: SliverToBoxAdapter(child: _InboxSkeleton()),
      ),
    ],
  );
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('inbox.loading.skeleton'),
    label: 'Cargando Bandeja',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SkeletonBlock(height: 58),
        const SizedBox(height: AppTokens.sp4),
        const Row(
          children: <Widget>[
            Expanded(child: _SkeletonBlock(height: 36)),
            SizedBox(width: AppTokens.sp2),
            Expanded(child: _SkeletonBlock(height: 36)),
            SizedBox(width: AppTokens.sp2),
            Expanded(child: _SkeletonBlock(height: 36)),
          ],
        ),
        const SizedBox(height: AppTokens.sp4),
        const _SkeletonBlock(height: 58),
        const SizedBox(height: AppTokens.sp5),
        for (var index = 0; index < 4; index++) ...<Widget>[
          const _SkeletonBlock(height: 82),
          if (index < 3) const SizedBox(height: 1),
        ],
      ],
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppTokens.surface2,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
    ),
  );
}

class InboxFailureView extends StatelessWidget {
  const InboxFailureView({super.key, required this.header, this.failure});

  final Widget header;
  final ConversationsFailure? failure;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: <Widget>[
      SliverToBoxAdapter(child: header),
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp5),
          child: Center(
            child: AppErrorState(
              key: const Key('inbox.error'),
              message: failure is ConversationsForbiddenFailure
                  ? 'Ya no tienes acceso a esta Bandeja'
                  : 'No pudimos cargar las conversaciones',
              onRetry: () => context.read<ConversationsBloc>().add(
                const ConversationsLoadRequested(),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
