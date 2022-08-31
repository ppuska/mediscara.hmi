import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:hmi_app/services/fiware.dart';
import 'package:hmi_app/services/session.dart';

class ControlWidget extends StatefulWidget {
  final Session visionSession;

  const ControlWidget({Key? key, required this.visionSession})
      : super(key: key);

  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  final controlService = FiwareService();
  final backendService = BackendService();

  final double rowHeight = 80;
  late Session visionSession;

  bool pcbMeasuring = false;
  String pcbConnectionMessage = "No result";
  String pcbMeasureMessage = "No data";
  bool labelMeasuring = false;
  String labelConnectionMessage = "No result";
  String labelMeasureMessage = "No data";

  final String? defaultRobotProgram = dotenv.env['DEFAULT_ROBOT_PROG'];
  final String? useManagerService = dotenv.env["USE_MANAGER"];

  final visionMcuId = dotenv.env["VISION_MCU_ID"];

  @override
  void initState() {
    super.initState();
    setState(() {
      visionSession = widget.visionSession;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void startSessionVision() {
    setState(() {
      visionSession.start();
    });
  }

  void pauseSessionVision() {
    setState(() {
      visionSession.pause();
    });
  }

  void homeVision() {
    sendHome().then(
      (value) => log(
        "Homing command was ${value ? 'successful' : 'unsuccessful'}",
      ),
    );
  }

  void measurePCB() async {
    String result;
    final sent = await sendMeasurePCB();

    if (sent) {
      dynamic response = await backendService.incomingRequest;

      /// The result is either 'RECEIVED' or 'BUSY'
      /// Response syntax:
      /// {
      ///   subscriptionId: ...,
      ///   data: [
      ///     {
      ///       id: ...,
      ///       ...
      ///       measure_label_info: ...
      ///     }
      ///   ]
      /// }
      result = response['data'][0]['measure_pcb_info']!;

      setState(() {
        pcbConnectionMessage = result;
      });

      if (result == "RECEIVED") {
        // await the second update
        setState(() {
          pcbMeasuring = true;
        });
        response = await backendService.incomingRequest;
        result = response['data'][0]['measure_pcb_info']!;

        setState(() {
          pcbMeasuring = false;
          pcbMeasureMessage = result;
        });
      }
    }
  }

  /// Sends the measure label command to the mcu
  void measureLabel() async {
    String result;
    final sent = await sendMeasureLabel(); // send the command

    if (sent) {
      dynamic response = await backendService.incomingRequest;

      /// The result is either 'RECEIVED' or 'BUSY'
      /// Response syntax:
      /// {
      ///   subscriptionId: ...,
      ///   data: [
      ///     {
      ///       id: ...,
      ///       ...
      ///       measure_label_info: ...
      ///     }
      ///   ]
      /// }
      result = response['data'][0]['measure_label_info']["value"]!;

      setState(() {
        labelConnectionMessage = result;
      });

      if (result == "RECEIVED") {
        // await the second update
        setState(() {
          labelMeasuring = true;
        });
        response = await backendService.incomingRequest;
        result = response['data'][0]['measure_label_info']["value"]!;

        setState(() {
          labelMeasuring = false;
          labelMeasureMessage = result;
        });
      }
    }
  }

  /// Callback method for the 'End session' button
  Future<void> endSessionVision() async {
    final result = await showConfirmationDialog();

    if (result ?? false) {
      setState(() {
        visionSession.end();
      });
    }
  }

  /// Shows a confirmation dialog and returns with a boolean depending on
  /// the answer
  Future<bool?> showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Are you sure?"),
          content: const Text("Do you want to end this session?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Vision",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: ElevatedButton(
                  onPressed: !visionSession.started ? startSessionVision : null,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Colors.lightGreen,
                    ),
                  ),
                  child: Container(
                    height: rowHeight,
                    alignment: Alignment.center,
                    child: const Text("Start session"),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                child: ElevatedButton(
                  onPressed: visionSession.started ? pauseSessionVision : null,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Colors.amber.shade300,
                    ),
                  ),
                  child: Container(
                    height: rowHeight,
                    alignment: Alignment.center,
                    child: Text(visionSession.paused ? "Resume" : "Pause"),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                child: ElevatedButton(
                  onPressed: visionSession.started ? endSessionVision : null,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Colors.deepOrange,
                    ),
                  ),
                  child: Container(
                    height: rowHeight,
                    alignment: Alignment.center,
                    child: const Text("End session"),
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ElevatedButton(
                  onPressed: visionSession.started && !visionSession.paused
                      ? homeVision
                      : null,
                  child: Container(
                    alignment: Alignment.center,
                    height: 50,
                    child: const Text("Home"),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: Card(
                  child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    alignment: Alignment.center,
                    child: const Text("Placeholder"),
                  ),
                ),
              ),
            )
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ElevatedButton(
                  onPressed: visionSession.started &&
                          !visionSession.paused &&
                          !labelMeasuring &&
                          !pcbMeasuring
                      ? measurePCB
                      : null,
                  child: Container(
                    alignment: Alignment.center,
                    height: rowHeight,
                    child: const Text("Measure pcb"),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: Card(
                  child: Container(
                    alignment: Alignment.center,
                    height: rowHeight,
                    child: Text("PCB: $pcbConnectionMessage"),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: Card(
                  child: Container(
                    alignment: Alignment.center,
                    height: rowHeight,
                    child: Text("Measurement: $pcbMeasureMessage"),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: pcbMeasuring,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  value: null,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: visionSession.started &&
                          !visionSession.paused &&
                          !labelMeasuring &&
                          !pcbMeasuring
                      ? measureLabel
                      : null,
                  child: Container(
                    alignment: Alignment.center,
                    height: rowHeight,
                    child: const Text("Measure Label"),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Container(
                  alignment: Alignment.center,
                  height: rowHeight,
                  child: Text("Label: $labelConnectionMessage"),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Container(
                  alignment: Alignment.center,
                  height: rowHeight,
                  child: Text("Measurement: $labelMeasureMessage"),
                ),
              ),
            ),
            Visibility(
              visible: labelMeasuring,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  value: null,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  height: rowHeight,
                  alignment: Alignment.center,
                  child: const Text("Placeholder"),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  height: rowHeight,
                  alignment: Alignment.center,
                  child: const Text("Placeholder"),
                ),
              ),
            ),
          ],
        ),
        const Text(
          "Marking",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Expanded(
          child: Card(
            child: Column(
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => {},
                      child: const Text("Start session"),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> sendMeasurePCB() async {
    final response = await controlService.sendCommand(
      command: 'measure_pcb',
      type: 'MCU',
      id: visionMcuId!,
      commandValue: {
        'prog': defaultRobotProgram!,
      },
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
    final response = await controlService.sendCommand(
      command: 'measure_label',
      type: 'MCU',
      id: visionMcuId!,
      commandValue: {
        'prog': defaultRobotProgram,
      },
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

  Future<bool> sendHome() async {
    final response = await controlService.sendCommand(
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
}
