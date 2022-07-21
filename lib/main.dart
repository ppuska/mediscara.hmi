import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:window_manager/window_manager.dart';

import 'login.dart';

Future main() async {
  await dotenv.load(fileName: ".env"); // load environment variables

  // open a http server to listen to backend calls
  final port = int.parse(dotenv.env["HTTP_LISTEN_PORT"] ?? '5000');

  final backendService = BackendService();
  await io.serve(backendService.router, InternetAddress.loopbackIPv4, port);

  await windowManager.ensureInitialized();
  if (kDebugMode) {
    await windowManager.maximize();
  } else {
    await windowManager.setFullScreen(true);
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
