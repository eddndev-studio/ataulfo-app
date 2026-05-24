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
  });

  factory MeResp.fromJson(Map<String, dynamic> json) {
    final user = json['user_id'];
    final org = json['org_id'];
    final role = json['role'];
    if (user is! String || org is! String || role is! String) {
      throw const FormatException('meResp: clave obligatoria ausente');
    }
    return MeResp(userId: user, orgId: org, role: role);
  }

  final String userId;
  final String orgId;
  final String role;
}
