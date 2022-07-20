import 'dart:convert';
import 'dart:developer';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/models/kpi.dart';
import 'package:hmi_app/services/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/access_token.dart';

class FiwareService {
  // ids of the entities in the ocb
  final visionMcuId = dotenv.env["VISION_MCU_ID"];
  final visionKpiId = dotenv.env["VISION_KPI_ID"];
  // url of the orion context broker
  final ocbUrl = dotenv.env["OCB_URL"];

  final fiwareService = dotenv.env["FIWARE_SERVICE"];
  final fiwareServicePath = dotenv.env["FIWARE_SERVICEPATH"];

  late AccessToken token;

  String _lastUsedId = "";
  String _lastUsedCommand = "";

  FiwareService() {
    getToken();
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

  void getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // token cannot be null
    token = AccessToken.fromJSON(
      jsonDecode(prefs.getString(AuthService.keyToken)!),
    );
  }

  Future<bool> sendHome() async {
    final response = await _sendCommand(
      "home",
      visionMcuId!,
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
      "measure_pcb",
      visionMcuId!,
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
      "measure_label",
      visionMcuId!,
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

  Future<http.Response> _sendCommand(String command, String id) async {
    _lastUsedCommand = command;
    _lastUsedId = id;
    log("Sending $command command to $id");
    return http.patch(
      Uri.parse("$ocbUrl/v2/entities/$id/attrs"),
      headers: {
        "X-Auth-token": token.accessToken,
        "Content-Type": "application/json",
        "fiware-service": fiwareService!,
        "fiware-servicepath": fiwareServicePath!,
      },
      body: jsonEncode(
        {
          command: {
            "type": "command",
            "value": "",
          },
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
        "X-Auth-token": token.accessToken,
        "fiware-service": fiwareService!,
        "fiware-servicepath": fiwareServicePath!,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["${_lastUsedCommand}_info"];
    }

    return null;
  }

  /// Fetches the measurement result (vision system)
  ///
  /// syntax of response:
  /// {type: Text, value: OK, metadata: {TimeInstant: {type: DateTime, value: 2022-07-19T09:20:54.168Z}}}
  Future<Map<String, dynamic>> getMeasurementResult() async {
    log("Fetching measurement results");
    final response = await http.get(
      Uri.parse("$ocbUrl/v2/entities/$visionMcuId"),
      headers: {
        "X-Auth-token": token.accessToken,
        'fiware-service': fiwareService!,
        'fiware-servicepath': fiwareServicePath!
      },
    );

    return jsonDecode(response.body)["measurement_result"];
  }

  Future<bool> sendKPI(KPI kpi) async {
    final response = await http.patch(
      Uri.parse("$ocbUrl/v2/entities/$visionKpiId/attrs"),
      headers: {
        "X-Auth-token": token.accessToken,
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
