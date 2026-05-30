import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_profile.dart';
import '../../domain/failures/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';

/// Bloc del perfil de un chat. Se construye con `botId` + `chatLid` (los aporta
/// la ruta) y carga una vez al pedir `ProfileLoadRequested`. Lo consumen tanto
/// el header del hilo (avatar + nombre) como la pantalla de perfil.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required ProfileRepository repo,
    required String botId,
    required String chatLid,
  }) : _repo = repo,
       _botId = botId,
       _chatLid = chatLid,
       super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoad);
  }

  final ProfileRepository _repo;
  final String _botId;
  final String _chatLid;

  Future<void> _onLoad(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      emit(ProfileLoaded(await _repo.fetch(_botId, _chatLid)));
    } on ProfileFailure catch (f) {
      emit(ProfileFailed(f));
    }
  }
}

// Events --------------------------------------------------------------------

sealed class ProfileEvent {
  const ProfileEvent();
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
  @override
  bool operator ==(Object other) => other is ProfileLoadRequested;
  @override
  int get hashCode => (ProfileLoadRequested).hashCode;
}

// States --------------------------------------------------------------------

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
  @override
  bool operator ==(Object other) => other is ProfileInitial;
  @override
  int get hashCode => (ProfileInitial).hashCode;
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
  @override
  bool operator ==(Object other) => other is ProfileLoading;
  @override
  int get hashCode => (ProfileLoading).hashCode;
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);

  final ChatProfile profile;

  @override
  bool operator ==(Object other) =>
      other is ProfileLoaded && other.profile == profile;
  @override
  int get hashCode => profile.hashCode;
}

class ProfileFailed extends ProfileState {
  const ProfileFailed(this.failure);

  final ProfileFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ProfileFailed && other.failure == failure;
  @override
  int get hashCode => failure.hashCode;
}
