import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_top_banner.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/resend_verification_cubit.dart';

/// Aviso de "verifica tu correo" del shell autenticado. Envuelve el contenido
/// de las tabs y pinta la franja SÓLO cuando la sesión está autenticada y el
/// correo no está verificado; en cuanto la identidad pasa a verificada (tras
/// canjear el token y refrescar la sesión) el aviso desaparece solo. La
/// coordinación con el status bar la aporta [AppTopBanner].
///
/// `AuthAuthenticatedNoOrg` no llega al shell (el router lo desvía a la
/// selección de organización), así que leer `AuthAuthenticated.identity` aquí
/// es seguro. Ofrece reenviar el correo (vía el cubit page-scoped del shell,
/// con un SnackBar de confirmación) y abrir la pantalla de verificación.
class EmailVerificationBanner extends StatelessWidget {
  const EmailVerificationBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final unverified =
            auth is AuthAuthenticated && !auth.identity.emailVerified;
        return AppTopBanner(
          visible: unverified,
          color: AppTokens.surface3,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp4,
            vertical: AppTokens.sp3,
          ),
          // El contenido (y con él el listener del reenvío) solo se monta con
          // la franja visible: una sesión verificada no exige el cubit.
          content: unverified
              ? _BannerBody(email: auth.identity.email)
              : const SizedBox.shrink(),
          child: child,
        );
      },
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
          // Sólo el botón observa el cubit: el loading inline del AppButton
          // bloquea re-taps durante el envío sin reconstruir el aviso entero.
          BlocBuilder<ResendVerificationCubit, ResendVerificationState>(
            builder: (context, state) {
              final sending = state is ResendVerificationSending;
              return AppButton.text(
                label: 'Reenviar',
                loading: sending,
                onPressed: () =>
                    context.read<ResendVerificationCubit>().resend(),
              );
            },
          ),
          AppButton.text(
            label: 'Verificar',
            onPressed: () => context.push(
              '/verify-email?email=${Uri.encodeQueryComponent(email)}',
            ),
          ),
        ],
      ),
    );
  }
}
