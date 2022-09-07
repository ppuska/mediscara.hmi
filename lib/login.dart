import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hmi_app/content.dart';
import 'package:hmi_app/services/auth.exceptions.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';

import 'services/auth.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({Key? key}) : super(key: key);

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late TextEditingController _emailEditingController;
  late TextEditingController _passwordEditingController;

  final AuthService _auth = AuthService();

  String _message = "";

  final _formKey = GlobalKey<FormState>();

  /// True if the keyboard is editing the email
  /// false if the keyboard is editing the password
  bool emailEditing = true;

  @override
  void initState() {
    super.initState();

    _emailEditingController = TextEditingController();
    _passwordEditingController = TextEditingController();

    if (kDebugMode) {
      setState(() {
        _emailEditingController.text = 'admin@test.com';
        _passwordEditingController.text = '1234';
      });
    }
  }

  @override
  void dispose() {
    _emailEditingController.dispose();
    _passwordEditingController.dispose();
    super.dispose();
  }

  void signIn() async {
    authenticate().then(
      (success) {
        if (success) {
          setState(() {
            _message = ""; // remove any old messages
          });
          // open the content page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContentWidget(),
            ),
          );
        }
      },
    );
  }

  Future<bool> authenticate() async {
    // validate the email first
    if (_formKey.currentState!.validate()) {
      // get the api token first
      final token = await _auth
          .getAPIToken(
        email: _emailEditingController.text,
        password: _passwordEditingController.text,
      )
          .catchError(
        (error) {
          log("Server unreachable");
          setState(() {
            _message = "Could not connect to the server";
          });
          return "";
        },
        test: (error) => error is ServerUnreachableException,
      ).catchError(
        (error) {
          log("Invalid credentials");
          setState(() {
            _message = "Email or password is invalid";
          });
          return "";
        },
        test: (error) => error is AuthenticationException,
      );

      if (token == "") return false;

      // get the oauth2 token
      await _auth.getOAuth2Token(
        email: _emailEditingController.text,
        password: _passwordEditingController.text,
      );

      // get the user from the oauth2 token
      await _auth.getUserFromToken();
      // gett the user roles with the api token
      await _auth.getUserRoles();
      await _auth.getRoles();

      return true;
    }
    return false;
  }

  void getUserWithToken(String token) {
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

  /// Processes the key presses from the [VirtualKeyboard]
  void processKeyPress(VirtualKeyboardKey key) {
    TextEditingController controller = _emailEditingController;
    if (!emailEditing) controller = _passwordEditingController;

    /// Process regular string keys
    if (key.keyType == VirtualKeyboardKeyType.String) {
      if (emailEditing) {
        // append the character or an empty string if it is null
        controller.text += key.text ?? "";
      } else {
        controller.text += key.text ?? "";
      }
    }

    /// Process action keys
    else if (key.keyType == VirtualKeyboardKeyType.Action) {
      switch (key.action) {
        case VirtualKeyboardKeyAction.Backspace:
          {
            /// Remove a character
            if (controller.text.isNotEmpty) {
              controller.text =
                  controller.text.substring(0, controller.text.length - 1);
            }
            break;
          }
        case VirtualKeyboardKeyAction.Return:
          {
            /// Switch from email edit to password edit
            if (emailEditing) {
              emailEditing = false;
            } else {
              /// after password editing, sign in the user
              signIn();
              emailEditing = true;
            }
            break;
          }
        default:
          {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
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
                      autofocus: true,
                      onTap: () => emailEditing = true,
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
                      onTap: () => emailEditing = false,
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Theme.of(context).primaryColorLight,
              child: VirtualKeyboard(
                height: 600,
                type: VirtualKeyboardType.Alphanumeric,
                onKeyPress: processKeyPress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
