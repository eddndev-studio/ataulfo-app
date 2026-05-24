import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Pantalla de Settings mínima del shell: muestra el rol del operador
/// (chip) y un botón para cerrar sesión. Otras opciones (tema, idioma,
/// perfil) aterrizan en su propio slice.
///
/// No muestra `userId` ni `orgId` crudos: hasta que `/auth/me` exponga
/// email/nombre, esos UUIDs no aportan al operador. Mostrarlos sería
/// ruido — el rol sí orienta al menos sobre privilegios efectivos.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          // El redirect del router cambia la ruta dentro del frame;
          // mostramos nada para evitar parpadeos UI durante transiciones.
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text('Rol'),
                  const SizedBox(width: 12),
                  Chip(label: Text(state.identity.role)),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () =>
                    context.read<AuthBloc>().add(const AuthLoggedOut()),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
      },
    );
  }
}
