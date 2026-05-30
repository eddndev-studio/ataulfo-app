import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../bloc/profile_bloc.dart';

/// App bar del hilo de mensajes con identidad real: avatar (foto) + nombre del
/// `ProfileBloc` del scope; al tocarlo abre "revisar perfil". Mientras carga (o
/// si falla) cae a un nombre neutro derivado del `chatLid`, sin bloquear el
/// hilo. Implementa `PreferredSizeWidget` para usarse como `Scaffold.appBar`.
class ChatThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatThreadAppBar({
    super.key,
    required this.botId,
    required this.chatLid,
  });

  final String botId;
  final String chatLid;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      titleSpacing: 0,
      title: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final (String name, String? photo) = switch (state) {
            ProfileLoaded(profile: final p) => (
              p.displayName ?? (p.isGroup ? 'Grupo' : (p.phone ?? chatLid)),
              p.photoUrl,
            ),
            _ => (chatLid, null),
          };
          // El header completo es un botón: el lector de pantalla lo anuncia
          // como control ("Ver perfil") en vez de leer el nombre como texto
          // inerte. ExcludeSemantics evita que el nombre se anuncie dos veces
          // (ya está en el label del Semantics y en el de AppAvatar).
          return Semantics(
            button: true,
            label: name,
            hint: 'Ver perfil',
            child: InkWell(
              onTap: () => context.push(
                '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}/profile',
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: <Widget>[
                    AppAvatar(name: name, size: 36, imageUrl: photo),
                    const SizedBox(width: AppTokens.sp3),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
