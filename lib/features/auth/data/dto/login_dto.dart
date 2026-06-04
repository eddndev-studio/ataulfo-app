/// DTOs del wire de autenticación (contrato S02).
///
/// Cualquier nombre `snake_case` vive aquí; el dominio expone `camelCase`
/// vía mappers. Las clases son inmutables y se construyen `const` cuando
/// el llamador puede hacerlo.
library;

class LoginReq {
  const LoginReq({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'password': password,
  };
}

class TokenResp {
  const TokenResp({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory TokenResp.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final type = json['token_type'];
    final expires = json['expires_in'];
    if (access is! String ||
        refresh is! String ||
        type is! String ||
        expires is! int) {
      throw const FormatException('tokenResp: clave obligatoria ausente');
    }
    return TokenResp(
      accessToken: access,
      refreshToken: refresh,
      tokenType: type,
      expiresIn: expires,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
}

class MeResp {
  const MeResp({
    required this.userId,
    required this.orgId,
    required this.role,
    required this.email,
    this.emailVerified = false,
  });

  factory MeResp.fromJson(Map<String, dynamic> json) {
    final user = json['user_id'];
    final org = json['org_id'];
    final role = json['role'];
    final email = json['email'];
    if (user is! String ||
        org is! String ||
        role is! String ||
        email is! String) {
      throw const FormatException('meResp: clave obligatoria ausente');
    }
    // `email_verified` ship en un slice posterior del backend; mientras no
    // esté mergeado su ausencia se tolera con default false. Sólo un bool
    // explícito lo activa — un tipo inesperado degrada a false sin romper.
    final verified = json['email_verified'];
    return MeResp(
      userId: user,
      orgId: org,
      role: role,
      email: email,
      emailVerified: verified is bool ? verified : false,
    );
  }

  final String userId;
  final String orgId;
  final String role;
  final String email;
  final bool emailVerified;
}

class RegisterReq {
  const RegisterReq({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'password': password,
  };
}

class VerifyEmailReq {
  const VerifyEmailReq({required this.token});

  final String token;

  Map<String, dynamic> toJson() => <String, dynamic>{'token': token};
}

class VerifyEmailResp {
  const VerifyEmailResp({required this.alreadyVerified});

  factory VerifyEmailResp.fromJson(Map<String, dynamic> json) {
    // Clave camelCase en el wire (a diferencia del resto, snake_case): el
    // contrato la fija así y el cliente la lee tal cual, sin normalizar.
    final already = json['alreadyVerified'];
    if (already is! bool) {
      throw const FormatException('verifyEmailResp: alreadyVerified ausente');
    }
    return VerifyEmailResp(alreadyVerified: already);
  }

  final bool alreadyVerified;
}

class ForgotPasswordReq {
  const ForgotPasswordReq({required this.email});

  final String email;

  Map<String, dynamic> toJson() => <String, dynamic>{'email': email};
}

class ResetPasswordReq {
  const ResetPasswordReq({required this.token, required this.newPassword});

  final String token;
  final String newPassword;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'new_password': newPassword,
  };
}

class SwitchOrgReq {
  const SwitchOrgReq({required this.orgId});

  final String orgId;

  Map<String, dynamic> toJson() => <String, dynamic>{'org_id': orgId};
}

class AcceptInvitationReq {
  const AcceptInvitationReq({required this.token});

  final String token;

  Map<String, dynamic> toJson() => <String, dynamic>{'token': token};
}
