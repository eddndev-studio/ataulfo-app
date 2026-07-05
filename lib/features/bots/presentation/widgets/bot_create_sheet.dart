import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/provider_badge.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/presentation/bloc/templates_bloc.dart';
import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';
import '../bloc/bot_create_bloc.dart';
import '../bot_create_draft.dart';

// Supera las 400 LOC a propósito: el wizard (los dos pasos + sus celdas, chip,
// vista de error y la lógica de borrador) es una sola unidad cohesiva de UI.
// Partirlo en archivos sólo dispersaría estado y callbacks que viven y se leen
// juntos; la legibilidad gana manteniéndolo aquí.

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
///
/// En el flujo libre (FAB / empty-state) la hoja recuerda el progreso: si el
/// usuario cierra el modal por accidente (tap fuera, swipe, back) y lo reabre,
/// recupera la plantilla elegida y el texto tecleado desde un
/// [BotCreateDraftStore] colgado del shell. El borrador se limpia sólo al crear
/// con éxito o al pulsar "Descartar". El flujo bloqueado (desde el detalle de
/// una plantilla) no usa borrador: su plantilla ya viene fija.
class BotCreateSheet extends StatefulWidget {
  const BotCreateSheet({super.key, this.initialTemplate, this.draftStore});

  /// Plantilla preseleccionada. Si es `null`, la hoja arranca en el paso de
  /// selección (que requiere un `TemplatesBloc` en el árbol).
  final Template? initialTemplate;

  /// Caché del borrador del wizard. `null` ⇒ la hoja no recuerda progreso
  /// (flujo bloqueado o usos de test aislados).
  final BotCreateDraftStore? draftStore;

  /// Abre la hoja y resuelve con el Bot creado, o `null` si se descartó sin
  /// crear. Con [template] omitido, el paso de selección reusa el
  /// `TemplatesBloc` del scope del llamador (el del shell) y se recuerda el
  /// progreso vía el `BotCreateDraftStore` del shell.
  static Future<Bot?> open(BuildContext context, {Template? template}) {
    final botsRepo = context.read<BotsRepository>();
    final templatesBloc = template == null
        ? context.read<TemplatesBloc>()
        : null;
    // El borrador sólo aplica al flujo libre: con plantilla fija no hay nada
    // que recordar entre aperturas.
    final draftStore = template == null
        ? context.read<BotCreateDraftStore>()
        : null;
    return showAppBottomSheet<Bot>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      builder: (_) {
        final sheet = BlocProvider<BotCreateBloc>(
          create: (_) => BotCreateBloc(repo: botsRepo),
          child: BotCreateSheet(
            initialTemplate: template,
            draftStore: draftStore,
          ),
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
  bool _hasContent = false;

  /// `true` si la hoja se abrió con plantilla ya elegida: en ese caso el paso de
  /// nombre no ofrece "volver" (no hay paso de selección al cual regresar).
  bool get _lockedTemplate => widget.initialTemplate != null;

  @override
  void initState() {
    super.initState();
    // Restaura el borrador (si lo hay) por encima de la plantilla preseleccionada
    // del flujo bloqueado, que nunca trae store.
    final draft = widget.draftStore?.current;
    if (draft != null) {
      _selected = draft.template ?? widget.initialTemplate;
      _nameCtrl.text = draft.name;
      _idCtrl.text = draft.identifier;
    } else {
      _selected = widget.initialTemplate;
    }
    _canSubmit = _nameCtrl.text.trim().isNotEmpty;
    _hasContent = _computeHasContent();
    _nameCtrl.addListener(_onChanged);
    _idCtrl.addListener(_onChanged);
  }

  bool _computeHasContent() =>
      _selected != null || _nameCtrl.text.isNotEmpty || _idCtrl.text.isNotEmpty;

  /// Reacciona a cualquier cambio de campo: recalcula los flags de UI (sólo
  /// hace setState si alguno realmente cambió) y deja el borrador al día, de
  /// modo que cerrar el modal nunca pierde progreso.
  void _onChanged() {
    final canSubmit = _nameCtrl.text.trim().isNotEmpty;
    final hasContent = _computeHasContent();
    if (canSubmit != _canSubmit || hasContent != _hasContent) {
      setState(() {
        _canSubmit = canSubmit;
        _hasContent = hasContent;
      });
    }
    _persistDraft();
  }

  void _persistDraft() {
    widget.draftStore?.save(
      BotCreateDraft(
        template: _selected,
        name: _nameCtrl.text,
        identifier: _idCtrl.text,
      ),
    );
  }

  void _selectTemplate(Template t) {
    setState(() => _selected = t);
    _onChanged();
  }

  void _clearSelection() {
    setState(() => _selected = null);
    _onChanged();
  }

  /// Descarte explícito: tira el borrador y cierra. A diferencia de tocar fuera
  /// del modal (que conserva el progreso), esto sí lo borra.
  void _discard() {
    widget.draftStore?.clear();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onChanged)
      ..dispose();
    _idCtrl
      ..removeListener(_onChanged)
      ..dispose();
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
          widget.draftStore?.clear();
          Navigator.of(context).pop(state.bot);
        }
      },
      builder: (context, state) {
        // "Descartar" sólo si hay borrador que tirar (flujo libre con contenido).
        final onDiscard = widget.draftStore != null && _hasContent
            ? _discard
            : null;
        final template = _selected;
        if (template == null) {
          return _PickStep(onPick: _selectTemplate, onDiscard: onDiscard);
        }
        return _NameStep(
          template: template,
          nameCtrl: _nameCtrl,
          idCtrl: _idCtrl,
          canSubmit: _canSubmit,
          submitting: state is BotCreateSubmitting,
          failure: state is BotCreateFailed ? state.failure : null,
          // Volver sólo si hubo paso de selección (no se entró bloqueada).
          onBack: _lockedTemplate ? null : _clearSelection,
          onSubmit: _submit,
          onDiscard: onDiscard,
        );
      },
    );
  }
}

/// Paso 1: elegir la plantilla base. Reusa el `TemplatesBloc` del shell. La
/// lista va acotada en altura para que la hoja no ocupe toda la pantalla.
class _PickStep extends StatelessWidget {
  const _PickStep({required this.onPick, this.onDiscard});

  final ValueChanged<Template> onPick;
  final VoidCallback? onDiscard;

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
          if (onDiscard != null) _DiscardButton(onPressed: onDiscard!),
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
          // Una plantilla no es una persona: mismo glifo de entidad que el
          // hub de Plantillas, nunca un avatar con inicial.
          const AppEntityIcon(icon: Icons.description_outlined),
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
    this.onDiscard,
  });

  final Template template;
  final TextEditingController nameCtrl;
  final TextEditingController idCtrl;
  final bool canSubmit;
  final bool submitting;
  final BotsFailure? failure;
  final VoidCallback? onBack;
  final VoidCallback onSubmit;
  final VoidCallback? onDiscard;

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
          if (onDiscard != null)
            // En vuelo se deshabilita (como "volver"): abandonar a media
            // creación dejaría el bot posiblemente creado en el server.
            _DiscardButton(onPressed: submitting ? null : onDiscard),
        ],
      ),
    );
  }
}

/// Acción secundaria, explícita y separada de cualquier gesto de "cerrar":
/// tira el borrador en curso. Cerrar el modal (tap fuera, swipe, back) conserva
/// el progreso; sólo este botón lo descarta. `onPressed` nulo lo deshabilita.
class _DiscardButton extends StatelessWidget {
  const _DiscardButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.sp2),
      child: Align(
        child: TextButton(
          key: const Key('bot_create.discard'),
          onPressed: onPressed,
          child: const Text(
            'Descartar',
            style: TextStyle(color: AppTokens.text2),
          ),
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    // Cápsula read-only del design system: el mismo patrón que el canal en la
    // hoja de edición del bot, en vez de una cápsula reconstruida a mano.
    return Align(
      key: const Key('bot_create.template_chip'),
      alignment: Alignment.centerLeft,
      child: AppPill.outline(label: name),
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
