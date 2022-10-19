import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/role.dart';
import '../models/user.dart';
import 'auth.exceptions.dart';

class AuthService {
  static const keyToken = "token";
  static const keyUser = "user";

  static AuthService? _instance;

  final _keyRockUrl = dotenv.env["KEYROCK_URL"];
  final _clientID = dotenv.env["CLIENT_ID"];
  final _clientSecret = dotenv.env["CLIENT_SECRET"];

  User? user;
  String? oauth2Token;
  String? apiToken;
  List<Role>? roles;

  AuthService._() {
    stdout.writeln("A new AuthService instance has been created");
  }

  factory AuthService() {
    return _instance ??= AuthService._();
  }

  /// Fetches an OAuth2 access token from the KeyRock IDM
  ///
  /// Throws an AuthenticationException if the authentication fails. <br>
  /// If the authentication was successful, it stores the token
  Future<String> getOAuth2Token({
    required String email,
    required String password,
  }) async {
    String credentials = "$_clientID:$_clientSecret";
    Codec<String, String> stringToBase64 = utf8.fuse(base64);

    String encoded = stringToBase64.encode(credentials);

    try {
      final response = await http.post(
        Uri.parse("$_keyRockUrl/oauth2/token"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Basic $encoded",
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: "username=$email&password=$password&grant_type=password",
      );

      if (response.statusCode == 200) {
        oauth2Token = jsonDecode(response.body)["access_token"]!;
        return oauth2Token!;
      }

      return Future.error(
        AuthenticationException(
          "Unable to get OAuth2 token (${response.statusCode}) ${response.body}",
        ),
      );
    } on SocketException {
      return Future.error(ServerUnreachableException());
    }
  }

  /// Generates an API token in the KeyRock IDM and returns in
  ///
  /// Throws an AuthenticationException if the authentication fails. <br>
  /// If the authentication was successful, it stores the token
  Future<String> getAPIToken({
    required String email,
    required String password,
  }) async {
    try {
      http.Response response = await http.post(
        Uri.parse("$_keyRockUrl/v1/auth/tokens"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": email,
          "password": password,
        }),
      );

      // success is 201 Created
      if (response.statusCode == 201) {
        // retreive the subject token from the response headers
        final subjectToken = response.headers['x-subject-token']!;
        response = await http.get(
          Uri.parse("$_keyRockUrl/v1/auth/tokens"),
          headers: {
            'x-auth-token': subjectToken,
            'x-subject-token': subjectToken,
          },
        );

        apiToken = jsonDecode(response.body)['access_token']!;

        return apiToken!;
      }

      if (response.statusCode == 503) {
        return Future.error(ServerUnreachableException());
      }

      return Future.error(
        AuthenticationException(
          "Unable to get API token: (${response.statusCode}) ${response.body}",
        ),
      );
    } on SocketException {
      return Future.error(ServerUnreachableException());
    }
  }

  /// Fetches the user with the access token
  ///
  /// If no access token is given, it uses the stored access token
  Future<User> getUserFromToken([String? token]) async {
    token ??= oauth2Token!;

    final response = await http.get(
      Uri.parse("$_keyRockUrl/user?access_token=$token"),
    );

    if (response.statusCode == 200) {
      user = User.fromJSON(jsonDecode(response.body)); // store the user
      return user!;
    }

    return Future.error(
      Exception("Unable to find user with token $token"),
    );
  }

  Future<User> getUserRoles({String? apiToken, User? user}) async {
    if (apiToken == null && this.apiToken == null) {
      return Future.error(
        UninitializedException("Fetch the API token first"),
      );
    }

    if (user == null && this.user == null) {
      return Future.error(
        UninitializedException("Fetch the user first"),
      );
    }

    apiToken ??= this.apiToken!;
    user ??= this.user!;

    final response = await http.get(
      Uri.parse(
        "$_keyRockUrl/v1/applications/$_clientID/users/${user.id}/roles",
      ),
      headers: {
        'x-auth-token': apiToken,
      },
    );

    /// response syntax:
    /// {
    ///   role_user_assignments: [
    ///     {
    ///       user_id: ...
    ///       role_id: ...
    ///     },
    ///     ...
    ///   ]
    /// }

    if (response.statusCode == 200) {
      final rawList = jsonDecode(response.body)['role_user_assignments'];

      for (var item in rawList) {
        user.roles.add(item['role_id']); //ad the role id to the list
      }
    } else {
      stdout.writeln("Error during role retrieval: ${response.body.toString()}");
    }

    this.user = user; // store the user

    stdout.writeln(user.toString());

    return user;
  }

  /// Fetches the roles of the application from the IDM
  Future<List<Role>> getRoles([String? apiToken]) async {
    apiToken ??= this.apiToken!;

    final response = await http.get(
      Uri.parse("$_keyRockUrl/v1/applications/$_clientID/roles"),
      headers: {
        'x-auth-token': apiToken,
      },
    );

    /// response syntax:
    /// {
    ///   roles: [
    ///     {
    ///       id: ...,
    ///       name: ...,
    ///     },
    ///     ...
    ///   ]
    /// }

    if (response.statusCode == 200) {
      final List<Role> roleList = [];
      final rawList = jsonDecode(response.body)['roles'];

      for (var item in rawList) {
        roleList.add(Role(id: item['id'], name: item['name']));
      }

      roles = roleList; // store the roles

      stdout.writeln("Got roles: ${roles.toString()}");

      return roleList;
    }

    return Future.error(
      AuthenticationException(
        'Unable to get roles: (${response.statusCode}) ${response.body}',
      ),
    );
  }
}
