import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/access_token.dart';
import '../models/user.dart';

class AuthService {
  static const keyToken = "token";
  static const keyUser = "user";

  final _keyRockUrl = dotenv.env["KEYROCK_URL"];
  final _clientID = dotenv.env["CLIENT_ID"];
  final _clientSecret = dotenv.env["CLIENT_SECRET"];

  Future<AccessToken> signIn({
    required String email,
    required String password,
  }) async {
    log("Authenticating using email '$email'");

    String credentials = "$_clientID:$_clientSecret";
    Codec<String, String> stringToBase64 = utf8.fuse(base64);

    String encoded = stringToBase64.encode(credentials);

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
      final token = AccessToken.fromJSON(jsonDecode(response.body));
      _storeToken(token);
      return token;
    }

    return Future.error(AuthenticationException(
      "Failed to authenticate, status code ${response.statusCode}, body ${response.body}",
    ));
  }

  Future<User> getUserFromToken(AccessToken token) async {
    log("Fetching user with access token ${token.accessToken}");
    final response = await http.get(
      Uri.parse("$_keyRockUrl/user?access_token=${token.accessToken}"),
    );

    if (response.statusCode == 200) {
      log(response.body);
      final user = User.fromJSON(jsonDecode(response.body));
      _storeUser(user);
      return user;
    }

    return Future.error(Exception());
  }

  void _storeUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJSON()));
  }

  void _storeToken(AccessToken token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', jsonEncode(token.toJSON()));
  }
}

class AuthenticationException implements Exception {
  final String msg;

  AuthenticationException(this.msg);

  @override
  String toString() {
    return "Authentication Exception: $msg";
  }
}
