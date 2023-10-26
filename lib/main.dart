import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:window_manager/window_manager.dart';

import 'login.dart';
import 'config.dart';

Future main() async {
  await dotenv.load(fileName: ".env"); // load environment variables

  // check mode
  final industrial = dotenv.env["INDUSTRIAL"];
  final collaborative = dotenv.env["COLLABORATIVE"];

  if (industrial != null) {
    Config.setMode(Config.industrial);
  } else if (collaborative != null) {
    Config.setMode(Config.collaborative);
  }

  if (Config.currentMode == -1) {
    stdout.writeln(
      "Define 'INDUSTRIAL' or 'COLLABORATIVE' environment variables to set the mode",
    );
    exit(1);
  }

  // open a http server to listen to backend calls
  final port = int.parse(dotenv.env["HTTP_LISTEN_PORT"] ?? '5000');

  final backendService = BackendService();
  await io.serve(backendService.router, InternetAddress.anyIPv4, port);

  if (Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1080, 1920));
  }

  runApp(const HMIApp());
}

class HMIApp extends StatelessWidget {
  const HMIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "HMI",
      home: const LoginWidget(),
      theme: ThemeData(
        colorSchemeSeed: const Color.fromARGB(255, 161, 80, 164),
        useMaterial3: true,
      ),
    );
  }
}
