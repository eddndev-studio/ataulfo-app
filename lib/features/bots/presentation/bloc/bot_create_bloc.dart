import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bot.dart';
import '../../domain/failures/bots_failure.dart';
import '../../domain/repositories/bots_repository.dart';

/// Bloc del flujo "crear bot". Mapea la acción del usuario a
/// `repo.create(...)` y expone estados que la UI consume directamente.
///
/// Las failures se exponen tal cual (sin enum intermedio): la UI hace el
/// switch exhaustivo sobre `BotsFailure` y elige copy. El sealed fuerza
/// al compilador a cubrir las variantes.
class BotCreateBloc extends Bloc<BotCreateEvent, BotCreateState> {
  BotCreateBloc({required BotsRepository repo})
    : _repo = repo,
      super(const BotCreateInitial()) {
    on<BotCreateSubmitted>(_onSubmitted);
  }

  final BotsRepository _repo;

  Future<void> _onSubmitted(
    BotCreateSubmitted event,
    Emitter<BotCreateState> emit,
  ) async {
    emit(const BotCreateSubmitting());
    try {
      final bot = await _repo.create(
        templateId: event.templateId,
        name: event.name,
        channel: event.channel,
      );
      emit(BotCreateSucceeded(bot));
    } on BotsFailure catch (e) {
      emit(BotCreateFailed(e));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class BotCreateEvent {
  const BotCreateEvent();
}

class BotCreateSubmitted extends BotCreateEvent {
  const BotCreateSubmitted({
    required this.templateId,
    required this.name,
    required this.channel,
  });

  final String templateId;
  final String name;
  final BotChannel channel;

  @override
  bool operator ==(Object other) =>
      other is BotCreateSubmitted &&
      other.templateId == templateId &&
      other.name == name &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(templateId, name, channel);
}

// States --------------------------------------------------------------------

sealed class BotCreateState {
  const BotCreateState();
}

class BotCreateInitial extends BotCreateState {
  const BotCreateInitial();

  @override
  bool operator ==(Object other) => other is BotCreateInitial;

  @override
  int get hashCode => (BotCreateInitial).hashCode;
}

class BotCreateSubmitting extends BotCreateState {
  const BotCreateSubmitting();

  @override
  bool operator ==(Object other) => other is BotCreateSubmitting;

  @override
  int get hashCode => (BotCreateSubmitting).hashCode;
}

class BotCreateSucceeded extends BotCreateState {
  const BotCreateSucceeded(this.bot);

  final Bot bot;

  @override
  bool operator ==(Object other) =>
      other is BotCreateSucceeded && other.bot == bot;

  @override
  int get hashCode => bot.hashCode;
}

class BotCreateFailed extends BotCreateState {
  const BotCreateFailed(this.failure);

  final BotsFailure failure;

  @override
  bool operator ==(Object other) =>
      other is BotCreateFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
