import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/chat_profile.dart';
import '../../domain/failures/profile_failure.dart';
import '../bloc/profile_bloc.dart';

/// Pantalla "revisar perfil" de una conversación: foto + nombre + phone/tipo y
/// el app-state (fijado/archivado/silenciado/no leído). Sólo lectura: las
/// acciones de mutación (fijar/silenciar/...) y la galería de media no forman
/// parte de esta pantalla. Content-only: el Scaffold/AppBar los aporta la ruta.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) => switch (state) {
        ProfileInitial() || ProfileLoading() => const Center(
          key: Key('profile.loading'),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        ProfileLoaded(profile: final p) => _ProfileView(profile: p),
        ProfileFailed(failure: final f) => _FailedView(failure: f),
      },
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.profile});

  final ChatProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = profile;
    final title =
        p.displayName ?? (p.isGroup ? 'Grupo' : (p.phone ?? p.chatLid));
    final subtitle = p.isGroup ? 'Grupo' : p.phone;

    final pills = <Widget>[
      if (p.isMarkedUnread) const AppPill.primary(label: 'No leído'),
      if (p.isPinned) const AppPill.neutral(label: 'Fijado'),
      if (p.isArchived) const AppPill.neutral(label: 'Archivado'),
      if (p.mutedUntil != null) const AppPill.neutral(label: 'Silenciado'),
    ];

    return ListView(
      key: const Key('profile.loaded'),
      padding: const EdgeInsets.all(AppTokens.sp6),
      children: <Widget>[
        Center(
          child: AppAvatar(name: title, size: 96, imageUrl: p.photoUrl),
        ),
        const SizedBox(height: AppTokens.sp4),
        Text(title, textAlign: TextAlign.center, style: textTheme.titleLarge),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: AppTokens.sp1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ],
        if (pills.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp5),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: pills,
          ),
        ],
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final ProfileFailure failure;

  @override
  Widget build(BuildContext context) {
    final isNotFound = failure is ProfileNotFoundFailure;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: isNotFound
          ? const Key('profile.error.not_found')
          : const Key('profile.error.generic'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isNotFound
                  ? 'Esta conversación ya no existe'
                  : 'No pudimos cargar el perfil',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () =>
                  context.read<ProfileBloc>().add(const ProfileLoadRequested()),
            ),
          ],
        ),
      ),
    );
  }
}
