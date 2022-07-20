import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hmi_app/content.dart';

import 'models/access_token.dart';
import 'services/auth.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({Key? key}) : super(key: key);

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late TextEditingController _emailEditingController;
  late TextEditingController _passwordEditingController;

  late AuthService _auth;

  String _message = "";

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _auth = AuthService();

    _emailEditingController = TextEditingController();
    _passwordEditingController = TextEditingController();
  }

  @override
  void dispose() {
    _emailEditingController.dispose();
    _passwordEditingController.dispose();
    super.dispose();
  }

  void signIn() {
    // validate the email first
    if (_formKey.currentState!.validate()) {
      _auth
          .signIn(
            email: _emailEditingController.text,
            password: _passwordEditingController.text,
          )
          .then(
            (token) => getUserWithToken(token),
          )
          .catchError(
            handleInvalidCredentialsError,
            test: (error) => error is AuthenticationException,
          )
          .catchError(
            handleSocketException,
            test: (error) => error is SocketException,
          );
    }
  }

  void getUserWithToken(AccessToken token) {
    _auth.getUserFromToken(token).then(
      (user) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ContentWidget(),
          ),
        );
      },
    );
  }

  AccessToken handleInvalidCredentialsError(Object exception) {
    log(exception.toString());
    setState(() {
      _message = "Email or password is invalid";
    });
    return AccessToken.empty();
  }

  AccessToken handleSocketException(Object exception) {
    log(exception.toString());
    setState(() {
      _message = "Cannot connect to the authentication server";
    });
    return AccessToken.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(10),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const Text(
                  'Sign in',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailEditingController,
                  validator: (String? value) {
                    if (value != null && value.isEmpty) {
                      return "This field is required";
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Email",
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordEditingController,
                  validator: (String? value) {
                    if (value != null && value.isEmpty) {
                      return "This field is required";
                    }
                    return null;
                  },
                  obscureText: true,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      onPressed: signIn,
                      icon: const Icon(Icons.login),
                    ),
                    border: const OutlineInputBorder(),
                    labelText: "Password",
                  ),
                ),
                Visibility(
                  visible: _message.isNotEmpty,
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.amber,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(_message),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
