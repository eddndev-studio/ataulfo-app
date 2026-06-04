import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/auth_failure.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/create_org_cubit.dart';

/// Pantalla para crear una organización nueva. Página content-only: la ruta
/// `/create-org` aporta Scaffold + AppBar.
///
/// El `CreateOrgCubit` persiste el par nuevo (la org creada queda activa); esta
/// página cierra el lazo: al éxito relee `/auth/me` (`AuthCheckRequested`) para
/// flipar la sesión y navega al shell. Navega a mano (a diferencia del switch
/// desde `/select-org`, que el redirect saca solo) porque `/create-org` no es
/// una ruta especial del redirect bajo `Authenticated`.
class CreateOrgPage extends StatefulWidget {
  const CreateOrgPage({super.key});

  @override
  State<CreateOrgPage> createState() => _CreateOrgPageState();
}

class _CreateOrgPageState extends State<CreateOrgPage> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController()..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameCtrl.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    context.read<CreateOrgCubit>().create(_nameCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateOrgCubit, CreateOrgState>(
      listener: (context, state) {
        switch (state) {
          case CreateOrgCreated():
            // El par nuevo ya está persistido; releer /auth/me flipa la sesión
            // a la org nueva y navegamos al shell (re-keyeado por orgId).
            context.read<AuthBloc>().add(const AuthCheckRequested());
            context.go('/home');
          case CreateOrgFailed(failure: final f):
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_failureMessage(f))));
          case CreateOrgIdle() || CreateOrgCreating():
            break;
        }
      },
      child: BlocBuilder<CreateOrgCubit, CreateOrgState>(
        builder: (context, state) {
          final creating = state is CreateOrgCreating;
          return Padding(
            padding: const EdgeInsets.all(AppTokens.sp6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  key: const Key('create_org.name'),
                  label: 'Nombre de la organización',
                  hint: 'Mi empresa',
                  controller: _nameCtrl,
                  enabled: !creating,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppTokens.sp5),
                AppButton.filled(
                  key: const Key('create_org.submit'),
                  label: 'Crear organización',
                  fullWidth: true,
                  loading: creating,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Create sólo produce, de forma realista, red o un fallo genérico (la
  /// pantalla valida el nombre no-vacío). No es un switch exhaustivo sobre el
  /// sellado: las otras variantes de AuthFailure no ocurren en este contexto.
  String _failureMessage(AuthFailure f) => f is NetworkFailure
      ? 'Sin conexión. Revisa tu red e inténtalo de nuevo.'
      : 'No pudimos crear la organización. Inténtalo de nuevo.';
}
