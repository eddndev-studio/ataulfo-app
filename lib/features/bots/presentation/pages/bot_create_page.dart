import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
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
  final TextEditingController _idCtrl = TextEditingController();
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
    _idCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final identifier = _idCtrl.text.trim();
    // WA_UNOFFICIAL es el único canal del cliente v1: WABA aterrizará con
    // el flujo de verificación que pide producto. El bloc recibe el
    // channel explícito para no asumir defaults dentro del dominio. El
    // `identifier` es opcional (label libre); vacío ⇒ no viaja.
    context.read<BotCreateBloc>().add(
      BotCreateSubmitted(
        templateId: widget.templateId,
        name: name,
        channel: BotChannel.waUnofficial,
        identifier: identifier.isEmpty ? null : identifier,
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
        return Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TemplateChip(name: widget.templateName),
              const SizedBox(height: AppTokens.sp6),
              AppTextField(
                key: const Key('bot_create.field.name'),
                label: 'Nombre del bot',
                hint: 'Ej. Bot soporte ventas',
                controller: _ctrl,
                enabled: !submitting,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_canSubmit) _submit();
                },
              ),
              const SizedBox(height: AppTokens.sp4),
              AppTextField(
                key: const Key('bot_create.field.identifier'),
                label: 'Identificador (opcional)',
                hint: 'Ej. número o etiqueta de referencia',
                controller: _idCtrl,
                enabled: !submitting,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_canSubmit) _submit();
                },
              ),
              const SizedBox(height: AppTokens.sp4),
              AppButton.filled(
                key: const Key('bot_create.submit'),
                label: 'Crear',
                // El primitivo bloquea el tap cuando loading=true sin
                // nullificar onPressed: pasamos el callback inalterado
                // y dejamos el gate de submitting al primitivo.
                onPressed: _canSubmit ? _submit : null,
                loading: submitting,
              ),
              if (state is BotCreateFailed) ...<Widget>[
                const SizedBox(height: AppTokens.sp4),
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
    final textTheme = Theme.of(context).textTheme;
    return Align(
      key: const Key('bot_create.template_chip'),
      alignment: Alignment.centerLeft,
      // Wrapper local: single callsite. Cuando un segundo page necesite
      // una etiqueta tipo "entidad seleccionada" con icono + label el
      // patrón sube a un primitivo (regla de 3). Hoy basta con un
      // Container con outline divider + fill surface2 + padding ~AppPill.
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp3,
          vertical: AppTokens.sp1,
        ),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          border: Border.all(color: AppTokens.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.description_outlined,
              size: 18,
              color: AppTokens.text2,
            ),
            const SizedBox(width: AppTokens.sp2),
            Text(
              name ?? 'Plantilla seleccionada',
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
            ),
          ],
        ),
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
      style: const TextStyle(color: AppTokens.danger),
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
    // BotsConflictFailure no es alcanzable por el create (su 409 = org no
    // activa → Unknown), pero el sealed exige cubrirlo: cae al genérico.
    BotsNotFoundFailure() ||
    BotsServerFailure() ||
    BotsConflictFailure() ||
    BotsNotPausedFailure() ||
    UnknownBotsFailure() => (
      'bot_create.error.generic',
      'No pudimos crear el bot. Inténtalo de nuevo.',
    ),
  };
}
