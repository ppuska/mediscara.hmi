class AuthenticationException implements Exception {
  final String msg;

  AuthenticationException(this.msg);

  @override
  String toString() {
    return "Authentication Exception: $msg";
  }
}

class UninitializedException implements Exception {
  final String msg;

  UninitializedException(this.msg);

  @override
  String toString() {
    return "Uninitialized Exception: $msg";
  }
}

class ServerUnreachableException implements Exception {
  @override
  String toString() {
    return "Server unreachable";
  }
}
