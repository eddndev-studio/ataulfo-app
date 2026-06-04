import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bots/domain/entities/bot.dart';
import '../../../bots/domain/repositories/bots_repository.dart';
import '../../domain/repositories/members_repository.dart';

/// Fase en la que falló la edición de asignación — la pantalla elige el copy y
/// la acción de reintento por esto.
enum AssignBotsPhase { load, save }

/// Cubit de la asignación de bots a un miembro (relevante sólo para WORKER;
/// SUPERVISOR+ ve todos). Cruza dos features: lista los bots de la org
/// (`BotsRepository`) y la asignación actual del miembro (`MembersRepository`),
/// y guarda el set COMPLETO (reemplazo; `[]` desasigna). El fallo es genérico
/// (atrapa ambas familias selladas) porque load-falló/save-falló no necesitan
/// UX distinta más allá del copy de fase.
class AssignBotsCubit extends Cubit<AssignBotsState> {
  AssignBotsCubit({
    required this.membershipId,
    required MembersRepository membersRepo,
    required BotsRepository botsRepo,
  }) : _membersRepo = membersRepo,
       _botsRepo = botsRepo,
       super(const AssignBotsLoading());

  final String membershipId;
  final MembersRepository _membersRepo;
  final BotsRepository _botsRepo;

  List<Bot> _bots = const <Bot>[];
  Set<String> _selected = const <String>{};

  Future<void> load() async {
    emit(const AssignBotsLoading());
    try {
      final bots = await _botsRepo.list();
      final assigned = await _membersRepo.assignedBots(membershipId);
      _bots = bots;
      _selected = assigned.toSet();
      emit(AssignBotsReady(bots: _bots, selected: _selected));
    } on Exception {
      // Atrapa BotsFailure y MembersFailure (dos sellados distintos): el copy
      // sólo depende de la fase, no del tipo exacto.
      emit(const AssignBotsFailed(AssignBotsPhase.load));
    }
  }

  void toggle(String botId) {
    if (state is! AssignBotsReady) return;
    final next = <String>{..._selected};
    if (!next.remove(botId)) next.add(botId);
    _selected = next;
    emit(AssignBotsReady(bots: _bots, selected: _selected));
  }

  Future<void> save() async {
    emit(const AssignBotsSaving());
    try {
      await _membersRepo.assignBots(membershipId, _selected.toList());
      emit(const AssignBotsSaved());
    } on Exception {
      emit(const AssignBotsFailed(AssignBotsPhase.save));
    }
  }

  /// Vuelve a la edición conservando la selección (tras un fallo de guardado el
  /// operador puede ajustar y reintentar sin perder lo elegido).
  void backToEditing() =>
      emit(AssignBotsReady(bots: _bots, selected: _selected));
}

// States --------------------------------------------------------------------

sealed class AssignBotsState {
  const AssignBotsState();
}

class AssignBotsLoading extends AssignBotsState {
  const AssignBotsLoading();
  @override
  bool operator ==(Object other) => other is AssignBotsLoading;
  @override
  int get hashCode => (AssignBotsLoading).hashCode;
}

class AssignBotsReady extends AssignBotsState {
  const AssignBotsReady({required this.bots, required this.selected});

  final List<Bot> bots;
  final Set<String> selected;

  bool isSelected(String botId) => selected.contains(botId);

  @override
  bool operator ==(Object other) =>
      other is AssignBotsReady &&
      listEquals(other.bots, bots) &&
      setEquals(other.selected, selected);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(bots), Object.hashAllUnordered(selected));
}

class AssignBotsSaving extends AssignBotsState {
  const AssignBotsSaving();
  @override
  bool operator ==(Object other) => other is AssignBotsSaving;
  @override
  int get hashCode => (AssignBotsSaving).hashCode;
}

class AssignBotsSaved extends AssignBotsState {
  const AssignBotsSaved();
  @override
  bool operator ==(Object other) => other is AssignBotsSaved;
  @override
  int get hashCode => (AssignBotsSaved).hashCode;
}

class AssignBotsFailed extends AssignBotsState {
  const AssignBotsFailed(this.phase);

  final AssignBotsPhase phase;

  @override
  bool operator ==(Object other) =>
      other is AssignBotsFailed && other.phase == phase;
  @override
  int get hashCode => phase.hashCode;
}
