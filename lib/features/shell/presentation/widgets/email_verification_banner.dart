import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/resend_verification_cubit.dart';

/// Aviso de "verifica tu correo" del shell autenticado. Se pinta sobre el
/// contenido de las tabs SÓLO cuando la sesión está autenticada y el correo no
/// está verificado; en cuanto la identidad pasa a verificada (tras canjear el
/// token y refrescar la sesión) el aviso desaparece solo.
///
/// `AuthAuthenticatedNoOrg` no llega al shell (el router lo desvía a la
/// selección de organización), así que leer `AuthAuthenticated.identity` aquí
/// es seguro. Ofrece reenviar el correo (vía el cubit page-scoped del shell,
/// con un SnackBar de confirmación) y abrir la pantalla de verificación.
class EmailVerificationBanner extends StatelessWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        if (auth is! AuthAuthenticated || auth.identity.emailVerified) {
          return const SizedBox.shrink();
        }
        return BlocListener<ResendVerificationCubit, ResendVerificationState>(
          listenWhen: (_, current) =>
              current is ResendVerificationSent ||
              current is ResendVerificationFailed,
          listener: (context, state) {
            final message = state is ResendVerificationFailed
                ? 'No pudimos reenviar el correo, reintenta'
                : 'Te reenviamos el correo';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
          child: const _BannerBody(),
        );
      },
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: AppTokens.surface3,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp4,
        vertical: AppTokens.sp3,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.mark_email_unread_outlined,
            color: AppTokens.warning,
            size: 20,
          ),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Text(
              'Verifica tu correo',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
            ),
          ),
          AppButton.text(
            label: 'Reenviar',
            onPressed: () => context.read<ResendVerificationCubit>().resend(),
          ),
          AppButton.text(
            label: 'Verificar',
            onPressed: () => context.push('/verify-email'),
          ),
        ],
      ),
    );
  }
}
