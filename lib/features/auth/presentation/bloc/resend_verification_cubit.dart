import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Cubit del reenvío del correo de verificación. Acción única: pedir al backend
/// que vuelva a mandar el correo al email de la sesión actual.
///
/// Es deliberadamente diminuto y vive scoped al aviso de "verifica tu correo":
/// el aviso lo dispara y reacciona a `Sent` con un SnackBar. Cualquier fallo
/// (red, backend) colapsa a `Failed` sin distinguir la causa — el reenvío es
/// reintentable y no hay copy por-kind que justifique más estados.
class ResendVerificationCubit extends Cubit<ResendVerificationState> {
  ResendVerificationCubit(this._repo) : super(const ResendVerificationIdle());

  final AuthRepository _repo;

  Future<void> resend() async {
    emit(const ResendVerificationSending());
    try {
      await _repo.resendVerification();
      emit(const ResendVerificationSent());
    } on AuthFailure {
      emit(const ResendVerificationFailed());
    }
  }
}

// States --------------------------------------------------------------------

sealed class ResendVerificationState {
  const ResendVerificationState();
}

class ResendVerificationIdle extends ResendVerificationState {
  const ResendVerificationIdle();

  @override
  bool operator ==(Object other) => other is ResendVerificationIdle;

  @override
  int get hashCode => (ResendVerificationIdle).hashCode;
}

class ResendVerificationSending extends ResendVerificationState {
  const ResendVerificationSending();

  @override
  bool operator ==(Object other) => other is ResendVerificationSending;

  @override
  int get hashCode => (ResendVerificationSending).hashCode;
}

class ResendVerificationSent extends ResendVerificationState {
  const ResendVerificationSent();

  @override
  bool operator ==(Object other) => other is ResendVerificationSent;

  @override
  int get hashCode => (ResendVerificationSent).hashCode;
}

class ResendVerificationFailed extends ResendVerificationState {
  const ResendVerificationFailed();

  @override
  bool operator ==(Object other) => other is ResendVerificationFailed;

  @override
  int get hashCode => (ResendVerificationFailed).hashCode;
}
