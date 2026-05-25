import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../bloc/bot_create_bloc.dart';

/// Página para crear un Bot ligado a una Template existente. Consume el
/// `BotCreateBloc` del scope; el cableado del provider y el path param lo
/// hace el router en `/templates/:templateId/bots/new`. Es content-only:
/// el Scaffold y el AppBar los aporta la ruta.
///
/// `templateName` es opcional: viene como query param desde la entry de
/// template-detail; en un deep-link directo a la URL sin el param, el
/// chip muestra un copy neutro en lugar del UUID.
class BotCreatePage extends StatefulWidget {
  const BotCreatePage({super.key, required this.templateId, this.templateName});

  final String templateId;
  final String? templateName;

  @override
  State<BotCreatePage> createState() => _BotCreatePageState();
}

class _BotCreatePageState extends State<BotCreatePage> {
  final TextEditingController _ctrl = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_recomputeCanSubmit);
  }

  void _recomputeCanSubmit() {
    final next = _ctrl.text.trim().isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_recomputeCanSubmit);
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    // WA_UNOFFICIAL es el único canal del cliente v1: WABA aterrizará con
    // el flujo de verificación que pide producto. El bloc recibe el
    // channel explícito para no asumir defaults dentro del dominio.
    context.read<BotCreateBloc>().add(
      BotCreateSubmitted(
        templateId: widget.templateId,
        name: name,
        channel: BotChannel.waUnofficial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BotCreateBloc, BotCreateState>(
      listener: (context, state) {
        if (state is BotCreateSucceeded) {
          // pushReplacement: reemplaza el formulario con el detalle del
          // bot recién creado (back del detalle NO vuelve al form que
          // ya cumplió) pero preserva el shell debajo. context.go()
          // aplastaría la pila y sacaría al usuario de la app al
          // presionar el back físico de Android.
          context.pushReplacement('/bots/${state.bot.id}');
        }
      },
      builder: (context, state) {
        final submitting = state is BotCreateSubmitting;
        final canTap = _canSubmit && !submitting;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TemplateChip(name: widget.templateName),
              const SizedBox(height: 24),
              TextField(
                key: const Key('bot_create.field.name'),
                controller: _ctrl,
                enabled: !submitting,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nombre del bot',
                  hintText: 'Ej. Bot soporte ventas',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (canTap) _submit();
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('bot_create.submit'),
                onPressed: canTap ? _submit : null,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crear'),
              ),
              if (state is BotCreateFailed) ...<Widget>[
                const SizedBox(height: 16),
                _FailedView(failure: state.failure),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: const Key('bot_create.template_chip'),
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: const Icon(Icons.description_outlined, size: 18),
        label: Text(name ?? 'Plantilla seleccionada'),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final BotsFailure failure;

  @override
  Widget build(BuildContext context) {
    final (key, copy) = _resolve(failure);
    return Text(
      copy,
      key: Key(key),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }

  static (String key, String copy) _resolve(BotsFailure f) => switch (f) {
    BotsInvalidCreateFailure() => (
      'bot_create.error.invalid_create',
      'Revisa los datos del bot: el nombre o la plantilla no son válidos.',
    ),
    BotsForbiddenFailure() => (
      'bot_create.error.forbidden',
      'Tu rol no permite crear bots. Pide acceso a un admin.',
    ),
    BotsNetworkFailure() || BotsTimeoutFailure() => (
      'bot_create.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    BotsNotFoundFailure() || BotsServerFailure() || UnknownBotsFailure() => (
      'bot_create.error.generic',
      'No pudimos crear el bot. Inténtalo de nuevo.',
    ),
  };
}
