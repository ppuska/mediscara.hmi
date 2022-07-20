class AccessToken {
  final String accessToken;
  final String? tokenType;
  final int? expiresIn;
  final String? refreshToken;

  const AccessToken({
    required this.accessToken,
    this.tokenType,
    this.expiresIn,
    this.refreshToken,
  }); // constructor

  factory AccessToken.fromJSON(Map<String, dynamic> json) {
    return AccessToken(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
      refreshToken: json['refresh_token'],
    );
  }

  factory AccessToken.fromString(String? token) {
    if (token == null) {
      return AccessToken.empty();
    }
    return AccessToken(accessToken: token);
  }

  factory AccessToken.empty() {
    return const AccessToken(accessToken: "");
  }

  Map<String, dynamic> toJSON() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'refreshToken': refreshToken,
    };
  }

  bool isEmpty() {
    return accessToken == "";
  }
}
