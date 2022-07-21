import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/models/kpi.dart';
import 'package:hmi_app/services/auth.dart';
import 'package:http/http.dart' as http;

class FiwareService {
  // ids of the entities in the ocb
  final visionMcuId = dotenv.env["VISION_MCU_ID"];
  final visionKpiId = dotenv.env["VISION_KPI_ID"];
  // url of the orion context broker
  final ocbUrl = dotenv.env["OCB_URL"];

  final fiwareService = dotenv.env["FIWARE_SERVICE"];
  final fiwareServicePath = dotenv.env["FIWARE_SERVICEPATH"];

  final auth = AuthService();

  String _lastUsedId = "";
  String _lastUsedCommand = "";

  FiwareService() {
    final environmentVars = [
      visionKpiId,
      visionMcuId,
      ocbUrl,
      fiwareService,
      fiwareServicePath,
    ];
    if (environmentVars.any((element) => element == null)) {
      throw Exception("Please set the environment variables.");
    }
  }

  Future<bool> sendHome() async {
    final response = await _sendCommand(
      command: 'home',
      type: 'MCU',
      id: visionMcuId!,
    );

    // the status code should be 'no content'
    if (response.statusCode == 204) {
      return true;
    }

    log(
      "Home command unsuccessful, status code ${response.statusCode}, body ${response.body}",
    );
    return false;
  }

  Future<bool> sendMeasurePCB() async {
    final response = await _sendCommand(
      command: 'measure_pcb',
      type: 'MCU',
      id: visionMcuId!,
    );

    // the status code should be 'no content'
    if (response.statusCode == 204) {
      return true;
    }

    log(
      "Measure PCB command unsuccessful, status code ${response.statusCode}, body ${response.body}",
    );
    return false;
  }

  Future<bool> sendMeasureLabel() async {
    final response = await _sendCommand(
      command: 'measure_label',
      type: 'MCU',
      id: visionMcuId!,
    );

    // the status code should be 'no content'
    if (response.statusCode == 204) {
      return true;
    }

    log(
      "Measure Label command unsuccessful, status code ${response.statusCode}, body ${response.body}",
    );
    return false;
  }

  Future<http.Response> _sendCommand({
    required String type,
    required String id,
    required String command,
    String? commandValue,
  }) async {
    _lastUsedCommand = command;
    _lastUsedId = id;
    log("Sending $command command to $id");
    return http.post(
      Uri.parse("$ocbUrl/v2/op/update"),
      headers: {
        "X-Auth-token": auth.oauth2Token!,
        "Content-Type": "application/json",
        "fiware-service": fiwareService!,
        "fiware-servicepath": fiwareServicePath!,
      },
      body: jsonEncode(
        {
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
        },
      ),
    );
  }

  /// Retrieves the last command result from the ocb
  ///
  /// Response syntax:
  /// {
  ///  "id": "urn:ngsi-ld:Bell:001",
  ///  "type": "Bell",
  ///  "TimeInstant": "2018-05-25T20:06:28.00Z",
  ///  "refStore": "urn:ngsi-ld:Store:001",
  ///  "ring_info": " ring OK",
  ///  "ring_status": "OK",
  ///  "ring": ""
  /// }
  Future<String?> get lastCommandResult async {
    if (_lastUsedId == "null" || _lastUsedCommand == "") return null;
    final response = await http.get(
      Uri.parse(
        "$ocbUrl/v2/entities/$_lastUsedId?options=keyValues",
      ),
      headers: {
        "X-Auth-token": auth.oauth2Token!,
        "fiware-service": fiwareService!,
        "fiware-servicepath": fiwareServicePath!,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["${_lastUsedCommand}_info"];
    }

    return null;
  }

  Future<bool> sendKPI(KPI kpi) async {
    final response = await http.patch(
      Uri.parse("$ocbUrl/v2/entities/$visionKpiId/attrs"),
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

    log(
      "Failed to update entity $visionKpiId, got (${response.statusCode}) ${response.body}",
    );
    return false;
  }
}
