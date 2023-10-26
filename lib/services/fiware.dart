import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/models/kpi.dart';
import 'package:hmi_app/services/auth.dart';
import 'package:http/http.dart' as http;

class FiwareService {
  // url of the orion context broker
  final ocbUrl = dotenv.env["OCB_URL"];

  final fiwareService = dotenv.env["FIWARE_SERVICE"];
  final fiwareServicePath = dotenv.env["FIWARE_SERVICEPATH"];

  final auth = AuthService();

  FiwareService() {
    final environmentVars = [
      ocbUrl,
      fiwareService,
      fiwareServicePath,
    ];
    if (environmentVars.any((element) => element == null)) {
      throw Exception("Please set the environment variables.");
    }
  }

  Future<Map<String, dynamic>?> getEntity({
    required String id,
    bool keyValues = false,
  }) async {
    final url = keyValues
        ? '$ocbUrl/v2/entities/$id?options=keyValues'
        : '$ocbUrl/v2/entities/$id';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "X-Auth-token": auth.oauth2Token!,
        "fiware-service": fiwareService!,
        "fiware-servicepath": fiwareServicePath!,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      stdout.writeln(
        "Unable to retrieve entity '$id': (${response.statusCode}) ${response.body}",
      );
      return null;
    }
  }

  Future<http.Response> sendCommand({
    required String type,
    required String id,
    required String command,
    dynamic commandValue,
  }) async {
    stdout.writeln("Sending $command command to $id");

    if ((commandValue is String?) || (commandValue is Map<String, dynamic>)) {
      final body = {
        "actionType": "update",
        "entities": [
          {
            'type': type,
            'id': id,
            command: {
              'type': 'command',
              'value': commandValue ?? '',
            }
          }
        ]
      };

      return http.post(
        Uri.parse("$ocbUrl/v2/op/update"),
        headers: {
          "X-Auth-token": auth.oauth2Token!,
          "Content-Type": "application/json",
          "fiware-service": fiwareService!,
          "fiware-servicepath": fiwareServicePath!,
        },
        body: jsonEncode(body),
      );
    }

    throw Exception('"commandValue" parameter should either be string or map');
  }

  Future<bool> sendKPI(KPI kpi, String id) async {
    final response = await http.patch(
      Uri.parse("$ocbUrl/v2/entities/$id/attrs"),
      headers: {
        "X-Auth-token": auth.oauth2Token!,
        "Content-Type": "application/json",
      },
      body: jsonEncode(
        kpi.toNGSIv2(),
      ),
    );

    if (response.statusCode == 204) {
      return true;
    }

    stdout.writeln(
      "Failed to update entity $id, got (${response.statusCode}) ${response.body}",
    );
    return false;
  }
}
