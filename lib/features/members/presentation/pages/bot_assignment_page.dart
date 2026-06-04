import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../bots/domain/entities/bot.dart';
import '../bloc/assign_bots_cubit.dart';

/// Pantalla para asignar bots a un miembro WORKER. Página content-only: la ruta
/// `/members/:id/bots` aporta Scaffold + AppBar y construye el `AssignBotsCubit`.
///
/// Lista los bots de la org con un check por bot (marcado = asignado). Guardar
/// envía el set COMPLETO (reemplazo); deseleccionar todo desasigna. Al guardar
/// con éxito cierra la pantalla y avisa.
class BotAssignmentPage extends StatelessWidget {
  const BotAssignmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssignBotsCubit, AssignBotsState>(
      listener: (context, state) {
        if (state is AssignBotsSaved) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Bots actualizados')));
        } else if (state is AssignBotsFailed &&
            state.phase == AssignBotsPhase.save) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pudimos guardar los cambios, reintenta'),
            ),
          );
          // Volvemos a la edición conservando la selección para reintentar.
          context.read<AssignBotsCubit>().backToEditing();
        }
      },
      child: BlocBuilder<AssignBotsCubit, AssignBotsState>(
        builder: (context, state) => switch (state) {
          AssignBotsLoading() || AssignBotsSaved() => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
            ),
          ),
          AssignBotsFailed(phase: AssignBotsPhase.load) => const _LoadFailed(),
          AssignBotsFailed() => const _SavingView(),
          AssignBotsSaving() => const _SavingView(),
          AssignBotsReady(bots: final bots, selected: final selected) =>
            _ReadyView(bots: bots, selected: selected, saving: false),
        },
      ),
    );
  }
}

class _SavingView extends StatelessWidget {
  const _SavingView();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
    ),
  );
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.bots,
    required this.selected,
    required this.saving,
  });

  final List<Bot> bots;
  final Set<String> selected;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    if (bots.isEmpty) {
      final textTheme = Theme.of(context).textTheme;
      return Center(
        key: const Key('bot_assignment.empty'),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Text(
            'Esta organización todavía no tiene bots que asignar',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bots.length,
            itemBuilder: (context, i) {
              final bot = bots[i];
              return CheckboxListTile(
                value: selected.contains(bot.id),
                title: Text(bot.name),
                onChanged: saving
                    ? null
                    : (_) => context.read<AssignBotsCubit>().toggle(bot.id),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTokens.sp4,
            AppTokens.sp2,
            AppTokens.sp4,
            AppTokens.sp4 + context.safeBottomInset,
          ),
          child: AppButton.filled(
            key: const Key('bot_assignment.save'),
            label: 'Guardar',
            fullWidth: true,
            loading: saving,
            onPressed: () => context.read<AssignBotsCubit>().save(),
          ),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      key: const Key('bot_assignment.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No pudimos cargar los bots',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTokens.sp3),
            AppButton.tonal(
              label: 'Reintentar',
              onPressed: () => context.read<AssignBotsCubit>().load(),
            ),
          ],
        ),
      ),
    );
  }
}
