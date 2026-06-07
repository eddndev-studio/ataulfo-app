import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_avatar.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/presentation/bloc/templates_bloc.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';
import '../bloc/bot_create_bloc.dart';

/// Hoja de creación de un Bot, en formato wizard de dos pasos dentro de un solo
/// bottom sheet: (1) elegir plantilla y (2) nombrar el bot. Reemplaza al par de
/// pantallas dedicadas (selector + formulario), conservando los pasos lógicos
/// pero sin la navegación intermedia.
///
/// Si se abre con una `template` preseleccionada (p. ej. desde el detalle de
/// una plantilla), arranca directamente en el paso de nombre y nunca consume el
/// `TemplatesBloc`. Al crear con éxito CIERRA devolviendo el Bot creado vía
/// `Navigator.pop`; quien la abre decide la navegación (empujar el detalle).
///
/// El modal vive fuera de los providers del shell: el repo de bots y —cuando
/// hace falta el paso de selección— el `TemplatesBloc` del shell se leen en el
/// call site y se inyectan a la hoja.
class BotCreateSheet extends StatefulWidget {
  const BotCreateSheet({super.key, this.initialTemplate});

  /// Plantilla preseleccionada. Si es `null`, la hoja arranca en el paso de
  /// selección (que requiere un `TemplatesBloc` en el árbol).
  final Template? initialTemplate;

  /// Abre la hoja y resuelve con el Bot creado, o `null` si se descartó sin
  /// crear. Con [template] omitido, el paso de selección reusa el
  /// `TemplatesBloc` del scope del llamador (el del shell).
  static Future<Bot?> open(BuildContext context, {Template? template}) {
    final botsRepo = context.read<BotsRepository>();
    final templatesBloc = template == null
        ? context.read<TemplatesBloc>()
        : null;
    return showModalBottomSheet<Bot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) {
        final sheet = BlocProvider<BotCreateBloc>(
          create: (_) => BotCreateBloc(repo: botsRepo),
          child: BotCreateSheet(initialTemplate: template),
        );
        return templatesBloc == null
            ? sheet
            : BlocProvider<TemplatesBloc>.value(
                value: templatesBloc,
                child: sheet,
              );
      },
    );
  }

  @override
  State<BotCreateSheet> createState() => _BotCreateSheetState();
}

class _BotCreateSheetState extends State<BotCreateSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  Template? _selected;
  bool _canSubmit = false;

  /// `true` si la hoja se abrió con plantilla ya elegida: en ese caso el paso de
  /// nombre no ofrece "volver" (no hay paso de selección al cual regresar).
  bool get _lockedTemplate => widget.initialTemplate != null;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTemplate;
    _nameCtrl.addListener(_recomputeCanSubmit);
  }

  void _recomputeCanSubmit() {
    final next = _nameCtrl.text.trim().isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    }
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_recomputeCanSubmit)
      ..dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final template = _selected;
    final name = _nameCtrl.text.trim();
    if (template == null || name.isEmpty) return;
    final identifier = _idCtrl.text.trim();
    context.read<BotCreateBloc>().add(
      BotCreateSubmitted(
        templateId: template.id,
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
          Navigator.of(context).pop(state.bot);
        }
      },
      builder: (context, state) {
        final template = _selected;
        if (template == null) {
          return _PickStep(onPick: (t) => setState(() => _selected = t));
        }
        return _NameStep(
          template: template,
          nameCtrl: _nameCtrl,
          idCtrl: _idCtrl,
          canSubmit: _canSubmit,
          submitting: state is BotCreateSubmitting,
          failure: state is BotCreateFailed ? state.failure : null,
          // Volver sólo si hubo paso de selección (no se entró bloqueada).
          onBack: _lockedTemplate
              ? null
              : () => setState(() => _selected = null),
          onSubmit: _submit,
        );
      },
    );
  }
}

/// Paso 1: elegir la plantilla base. Reusa el `TemplatesBloc` del shell. La
/// lista va acotada en altura para que la hoja no ocupe toda la pantalla.
class _PickStep extends StatelessWidget {
  const _PickStep({required this.onPick});

  final ValueChanged<Template> onPick;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.sheetBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Elegir plantilla', style: textTheme.titleLarge),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'El bot heredará el comportamiento de la plantilla que elijas.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp4),
          BlocBuilder<TemplatesBloc, TemplatesState>(
            builder: (context, state) => switch (state) {
              TemplatesInitial() || TemplatesLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTokens.sp6),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTokens.primary,
                    ),
                  ),
                ),
              ),
              TemplatesLoaded(items: final items) => _PickList(
                items: items,
                onPick: onPick,
              ),
              TemplatesFailed() => const _PickFailed(),
            },
          ),
        ],
      ),
    );
  }
}

class _PickList extends StatelessWidget {
  const _PickList({required this.items, required this.onPick});

  final List<Template> items;
  final ValueChanged<Template> onPick;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _PickEmpty();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTokens.cardGap),
        itemBuilder: (_, i) => _PickTile(template: items[i], onPick: onPick),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.template, required this.onPick});

  final Template template;
  final ValueChanged<Template> onPick;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      key: Key('bot_create.pick.${template.id}'),
      onTap: () => onPick(template),
      child: Row(
        children: <Widget>[
          AppAvatar(name: template.name),
          const SizedBox(width: AppTokens.sp4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(template.name, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                ProviderBadge(provider: template.ai.provider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickEmpty extends StatelessWidget {
  const _PickEmpty();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('bot_create.pick.empty'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('No tienes plantillas todavía.', style: textTheme.bodyLarge),
          const SizedBox(height: AppTokens.sp2),
          Text(
            'Crea una desde la tab Plantillas para poder crear bots.',
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ],
      ),
    );
  }
}

class _PickFailed extends StatelessWidget {
  const _PickFailed();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const Key('bot_create.pick.error'),
      padding: const EdgeInsets.symmetric(vertical: AppTokens.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('No pudimos cargar tus plantillas', style: textTheme.bodyLarge),
          const SizedBox(height: AppTokens.sp3),
          AppButton.tonal(
            label: 'Reintentar',
            onPressed: () => context.read<TemplatesBloc>().add(
              const TemplatesLoadRequested(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paso 2: nombre + identificador del bot, con la plantilla elegida resumida en
/// un chip. Es el formulario que antes vivía en su pantalla dedicada.
class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.template,
    required this.nameCtrl,
    required this.idCtrl,
    required this.canSubmit,
    required this.submitting,
    required this.failure,
    required this.onBack,
    required this.onSubmit,
  });

  final Template template;
  final TextEditingController nameCtrl;
  final TextEditingController idCtrl;
  final bool canSubmit;
  final bool submitting;
  final BotsFailure? failure;
  final VoidCallback? onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6,
        AppTokens.sp6 + context.sheetBottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (onBack != null) ...<Widget>[
                IconButton(
                  key: const Key('bot_create.back'),
                  tooltip: 'Elegir otra plantilla',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: submitting ? null : onBack,
                ),
                const SizedBox(width: AppTokens.sp1),
              ],
              Expanded(child: Text('Nuevo bot', style: textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: AppTokens.sp4),
          _TemplateChip(name: template.name),
          const SizedBox(height: AppTokens.sp4),
          AppTextField(
            key: const Key('bot_create.field.name'),
            label: 'Nombre del bot',
            hint: 'Ej. Bot soporte ventas',
            controller: nameCtrl,
            enabled: !submitting,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canSubmit) onSubmit();
            },
          ),
          const SizedBox(height: AppTokens.sp4),
          AppTextField(
            key: const Key('bot_create.field.identifier'),
            label: 'Identificador (opcional)',
            hint: 'Ej. número o etiqueta de referencia',
            controller: idCtrl,
            enabled: !submitting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canSubmit) onSubmit();
            },
          ),
          const SizedBox(height: AppTokens.sp4),
          AppButton.filled(
            key: const Key('bot_create.submit'),
            label: 'Crear',
            fullWidth: true,
            onPressed: canSubmit ? onSubmit : null,
            loading: submitting,
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: AppTokens.sp4),
            _FailedView(failure: failure!),
          ],
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      key: const Key('bot_create.template_chip'),
      alignment: Alignment.centerLeft,
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
              name,
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
