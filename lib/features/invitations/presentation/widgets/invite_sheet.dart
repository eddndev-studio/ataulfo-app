import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_bottom_sheet.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_checkbox_row.dart';
import '../../../../core/design/widgets/app_entity_icon.dart';
import '../../../../core/design/widgets/app_notice_banner.dart';
import '../../../../core/design/widgets/app_radio_row.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_wizard_sheet.dart';
import '../../../../core/i18n/role_labels.dart';
import '../../../../core/platform/share_service.dart';
import '../../../bots/domain/entities/bot.dart';
import '../../domain/failures/invitations_failure.dart';
import '../../domain/repositories/invitations_repository.dart';
import '../bloc/invitation_mutation_cubit.dart';
import '../invitation_failure_copy.dart';
import 'invitation_share_sheet.dart';

enum _InviteStep { person, access }

/// Wizard persistente para crear una invitación.
///
/// La mutación vive dentro de la ruta del sheet: al enviar no se cierra ni se
/// abre una segunda hoja. El mismo modal muestra progreso, conserva el borrador
/// ante un fallo y, al terminar, se transforma en el estado para copiar o
/// compartir el código.
class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.bots, this.shareService});

  final List<Bot> bots;
  final ShareService? shareService;

  // OWNER se excluye a propósito: la propiedad se transfiere desde Miembros;
  // nunca se concede saltándose ese flujo mediante una invitación.
  static const List<String> roleOptions = <String>[
    'WORKER',
    'SUPERVISOR',
    'ADMIN',
  ];

  /// Abre el wizard y devuelve si el historial debe recargarse.
  ///
  /// Un éxito siempre recarga. También lo hace un fallo 5xx porque el backend
  /// pudo guardar la fila antes de fallar al enviar el correo.
  static Future<bool> open(
    BuildContext context, {
    required List<Bot> bots,
    ShareService? shareService,
  }) async {
    final cubit = InvitationMutationCubit(
      context.read<InvitationsRepository>(),
    );
    final sheetKey = GlobalKey<_InviteSheetState>();

    final result = await showAppBottomSheet<bool>(
      context,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface1,
      confirmDiscard: () =>
          sheetKey.currentState?.shouldConfirmDiscard ?? false,
      canDismiss: () => sheetKey.currentState?.canDismiss ?? true,
      // `create` hace al provider dueño del cubit: lo cierra cuando la ruta
      // termina su animación de salida. El estado final sigue disponible para
      // decidir si el listado quedó potencialmente desfasado.
      builder: (_) => BlocProvider<InvitationMutationCubit>(
        lazy: false,
        create: (_) => cubit,
        child: InviteSheet(
          key: sheetKey,
          bots: bots,
          shareService: shareService,
        ),
      ),
    );
    final finalState = cubit.state;
    final shouldRefresh =
        (finalState is InvitationMutationSuccess &&
            finalState.action == InvitationMutationAction.created) ||
        (finalState is InvitationMutationFailure &&
            finalState.failure is InvitationsServerFailure);
    return result ?? shouldRefresh;
  }

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  static const int _searchThreshold = 6;
  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s.]+$');

  late final TextEditingController _emailCtrl;
  late final TextEditingController _searchCtrl;
  final Set<String> _selectedBotIds = <String>{};

  _InviteStep _step = _InviteStep.person;
  String _role = 'WORKER';

  InvitationMutationState get _mutationState =>
      context.read<InvitationMutationCubit>().state;

  bool get _isSubmitting => _mutationState is InvitationMutationInProgress;

  bool get _isCreated =>
      _mutationState is InvitationMutationSuccess &&
      (_mutationState as InvitationMutationSuccess).action ==
          InvitationMutationAction.created;

  bool get canDismiss => !_isSubmitting;

  bool get shouldConfirmDiscard =>
      !_isCreated &&
      (_emailCtrl.text.trim().isNotEmpty ||
          _step == _InviteStep.access ||
          _role != 'WORKER' ||
          _selectedBotIds.isNotEmpty);

  bool get _hasValidEmail => _emailShape.hasMatch(_emailCtrl.text.trim());

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController()..addListener(_onEmailChanged);
    _searchCtrl = TextEditingController()..addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _emailCtrl
      ..removeListener(_onEmailChanged)
      ..dispose();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    _clearFailure();
    setState(() {});
  }

  void _onSearchChanged() => setState(() {});

  void _clearFailure() {
    final cubit = context.read<InvitationMutationCubit>();
    if (cubit.state is InvitationMutationFailure) {
      cubit.reset();
    }
  }

  void _continue() {
    if (!_hasValidEmail) return;
    _clearFailure();
    setState(() => _step = _InviteStep.access);
  }

  void _back() {
    if (_isSubmitting) return;
    _clearFailure();
    setState(() => _step = _InviteStep.person);
  }

  void _selectRole(String role) {
    if (_isSubmitting || role == _role) return;
    _clearFailure();
    setState(() => _role = role);
  }

  void _selectBot(String id, bool selected) {
    if (_isSubmitting) return;
    _clearFailure();
    setState(() {
      if (selected) {
        _selectedBotIds.add(id);
      } else {
        _selectedBotIds.remove(id);
      }
    });
  }

  void _submit() {
    if (_isSubmitting || !_hasValidEmail) return;
    final botIds = _role == 'WORKER'
        ? (_selectedBotIds.toList(growable: false)..sort())
        : const <String>[];
    unawaited(
      context.read<InvitationMutationCubit>().create(
        _emailCtrl.text.trim(),
        _role,
        botIds,
      ),
    );
  }

  void _finish() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvitationMutationCubit, InvitationMutationState>(
      builder: (context, state) {
        final success =
            state is InvitationMutationSuccess &&
            state.action == InvitationMutationAction.created;

        return AnimatedSwitcher(
          duration: AppTokens.durationSlow,
          switchInCurve: AppTokens.ease,
          switchOutCurve: AppTokens.ease,
          child: success
              ? InvitationShareSheet(
                  key: const ValueKey<String>('invite.success'),
                  email: state.email ?? _emailCtrl.text.trim(),
                  token: state.token,
                  emailSent: state.emailSent,
                  shareService: widget.shareService,
                  onDone: _finish,
                )
              : AppWizardSheet(
                  key: ValueKey<_InviteStep>(_step),
                  body: _step == _InviteStep.person
                      ? _PersonStep(
                          controller: _emailCtrl,
                          canContinue: _hasValidEmail,
                          onSubmitted: _continue,
                        )
                      : _AccessStep(
                          email: _emailCtrl.text.trim(),
                          bots: widget.bots,
                          searchController: _searchCtrl,
                          showSearch: widget.bots.length >= _searchThreshold,
                          role: _role,
                          selectedBotIds: _selectedBotIds,
                          submitting: state is InvitationMutationInProgress,
                          onRoleChanged: _selectRole,
                          onBotChanged: _selectBot,
                        ),
                  footer: _footer(state),
                ),
        );
      },
    );
  }

  Widget _footer(InvitationMutationState state) {
    if (_step == _InviteStep.person) {
      return Row(
        children: <Widget>[
          Expanded(
            child: AppButton.tonal(
              key: const Key('invite.cancel'),
              label: 'Cancelar',
              fullWidth: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: AppButton.filled(
              key: const Key('invite.continue'),
              label: 'Continuar',
              fullWidth: true,
              onPressed: _hasValidEmail ? _continue : null,
            ),
          ),
        ],
      );
    }

    final submitting = state is InvitationMutationInProgress;
    final failure = state is InvitationMutationFailure ? state.failure : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (failure != null) ...<Widget>[
          AppNoticeBanner.danger(
            key: const Key('invite.failure'),
            message: invitationFailureMessage(failure),
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton.tonal(
                key: const Key('invite.back'),
                label: 'Atrás',
                fullWidth: true,
                onPressed: submitting ? null : _back,
              ),
            ),
            const SizedBox(width: AppTokens.sp3),
            Expanded(
              child: AppButton.filled(
                key: const Key('invite.submit'),
                label: submitting ? 'Creando invitación…' : 'Enviar invitación',
                fullWidth: true,
                loading: submitting,
                onPressed: submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonStep extends StatelessWidget {
  const _PersonStep({
    required this.controller,
    required this.canContinue,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool canContinue;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('invite.step.person'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppWizardStepHeader(
          step: 1,
          totalSteps: 2,
          title: 'Persona',
          description:
              'Escribe el correo que usará para entrar a la organización.',
        ),
        const SizedBox(height: AppTokens.sp5),
        AppTextField(
          key: const Key('invite.email'),
          label: 'Correo electrónico',
          hint: 'persona@empresa.com',
          controller: controller,
          autofocus: true,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          helperText:
              'La invitación y el acceso quedarán vinculados a este correo.',
          onSubmitted: (_) {
            if (canContinue) onSubmitted();
          },
        ),
      ],
    );
  }
}

class _AccessStep extends StatelessWidget {
  const _AccessStep({
    required this.email,
    required this.bots,
    required this.searchController,
    required this.showSearch,
    required this.role,
    required this.selectedBotIds,
    required this.submitting,
    required this.onRoleChanged,
    required this.onBotChanged,
  });

  final String email;
  final List<Bot> bots;
  final TextEditingController searchController;
  final bool showSearch;
  final String role;
  final Set<String> selectedBotIds;
  final bool submitting;
  final ValueChanged<String> onRoleChanged;
  final void Function(String id, bool selected) onBotChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('invite.step.access'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppWizardStepHeader(
          step: 2,
          totalSteps: 2,
          title: 'Acceso',
          description:
              'Elige lo que podrá ver y gestionar dentro de la organización.',
        ),
        const SizedBox(height: AppTokens.sp5),
        AppCard.outline(
          key: const Key('invite.email_summary'),
          padding: const EdgeInsets.all(AppTokens.sp3),
          child: Row(
            children: <Widget>[
              const AppEntityIcon(
                icon: Icons.alternate_email,
                size: 40,
                highlighted: true,
              ),
              const SizedBox(width: AppTokens.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Persona invitada',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                    ),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.sp5),
        Text('Rol', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTokens.sp2),
        AppCard.outline(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.sp2,
            vertical: AppTokens.sp1,
          ),
          child: Column(
            children: <Widget>[
              for (
                var index = 0;
                index < InviteSheet.roleOptions.length;
                index++
              ) ...<Widget>[
                _RoleRow(
                  role: InviteSheet.roleOptions[index],
                  selectedRole: role,
                  enabled: !submitting,
                  onChanged: onRoleChanged,
                ),
                if (index < InviteSheet.roleOptions.length - 1)
                  const Divider(height: 1, color: AppTokens.divider),
              ],
            ],
          ),
        ),
        if (role == 'WORKER') ...<Widget>[
          const SizedBox(height: AppTokens.sp5),
          _ChannelsSection(
            bots: bots,
            searchController: searchController,
            showSearch: showSearch,
            selectedBotIds: selectedBotIds,
            enabled: !submitting,
            onChanged: onBotChanged,
          ),
        ],
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.selectedRole,
    required this.enabled,
    required this.onChanged,
  });

  final String role;
  final String selectedRole;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final details = switch (role) {
      'WORKER' => (
        icon: Icons.support_agent_outlined,
        description: 'Atiende únicamente los Canales que selecciones.',
      ),
      'SUPERVISOR' => (
        icon: Icons.insights_outlined,
        description: 'Supervisa todos los Canales operativos.',
      ),
      'ADMIN' => (
        icon: Icons.admin_panel_settings_outlined,
        description: 'Gestiona el equipo y configuración de la organización.',
      ),
      _ => (
        icon: Icons.person_outline,
        description: 'Acceso definido por la organización.',
      ),
    };

    return AppRadioRow<String>(
      key: Key('invite.role.$role'),
      value: role,
      groupValue: selectedRole,
      onChanged: enabled ? onChanged : null,
      title: roleLabel(role),
      subtitle: details.description,
      leading: AppEntityIcon(
        icon: details.icon,
        size: 40,
        highlighted: role == selectedRole,
      ),
    );
  }
}

class _ChannelsSection extends StatelessWidget {
  const _ChannelsSection({
    required this.bots,
    required this.searchController,
    required this.showSearch,
    required this.selectedBotIds,
    required this.enabled,
    required this.onChanged,
  });

  final List<Bot> bots;
  final TextEditingController searchController;
  final bool showSearch;
  final Set<String> selectedBotIds;
  final bool enabled;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? bots
        : bots
              .where((bot) => bot.name.toLowerCase().contains(query))
              .toList(growable: false);

    return Column(
      key: const Key('invite.channels'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Canales',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${selectedBotIds.length} de ${bots.length} seleccionados',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sp2),
        if (selectedBotIds.isEmpty) ...<Widget>[
          AppNoticeBanner.info(
            key: const Key('invite.channels.assign_later'),
            icon: Icons.schedule_outlined,
            message: bots.isEmpty
                ? 'Todavía no hay Canales. Podrás asignarlos después.'
                : 'Puedes continuar sin acceso y asignarlos después.',
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
        if (showSearch) ...<Widget>[
          AppSearchField(
            key: const Key('invite.channels.search'),
            hint: 'Buscar Canales por nombre',
            controller: searchController,
            enabled: enabled,
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
        if (filtered.isNotEmpty)
          AppCard.outline(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp2,
              vertical: AppTokens.sp1,
            ),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < filtered.length; index++) ...[
                  _ChannelRow(
                    bot: filtered[index],
                    selected: selectedBotIds.contains(filtered[index].id),
                    enabled: enabled,
                    onChanged: onChanged,
                  ),
                  if (index < filtered.length - 1)
                    const Divider(height: 1, color: AppTokens.divider),
                ],
              ],
            ),
          )
        else if (bots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.sp3),
            child: Center(
              child: Text(
                'No encontramos Canales con ese nombre.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.bot,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final Bot bot;
  final bool selected;
  final bool enabled;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCheckboxRow(
      key: Key('invite.channel.${bot.id}'),
      value: selected,
      onChanged: enabled ? (value) => onChanged(bot.id, value) : null,
      title: bot.name,
      subtitle: switch (bot.channel) {
        BotChannel.waba => 'WhatsApp Business',
        BotChannel.waUnofficial => 'WhatsApp vinculado',
      },
      leading: AppEntityIcon(
        letter: bot.name.trim().isEmpty
            ? '?'
            : bot.name.trim().characters.first.toUpperCase(),
        size: 36,
        highlighted: selected,
      ),
    );
  }
}
