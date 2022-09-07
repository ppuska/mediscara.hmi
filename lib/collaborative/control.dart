import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:hmi_app/services/fiware.dart';
import 'package:hmi_app/services/session.dart';

class ControlWidget extends StatefulWidget {
  final Session visionSession;
  final Session markingSession;

  const ControlWidget({
    Key? key,
    required this.visionSession,
    required this.markingSession,
  }) : super(key: key);

  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  final controlService = FiwareService();
  final backendService = BackendService();

  final double rowHeight = 80;

  late Session visionSession;
  late Session markingSession;

  /// Message to be displayed next to the home button
  String homeMessage = '';

  String maintenanceMessage = '27 days';

  bool isMarking = false;
  String labelMarking = '';

  bool pcbMeasuring = false;
  String pcbMeasureMessage = "No data";
  bool labelMeasuring = false;
  String labelMeasureMessage = "No data";
  bool assemblyMeasuring = false;
  String assemblyMeasureMessage = "No data";

  final String? defaultRobotProgram = dotenv.env['DEFAULT_ROBOT_PROG'];
  final String? useManagerService = dotenv.env["USE_MANAGER"];

  final visionMcuId = dotenv.env["COLLABORATIVE_MCU_ID"];

  @override
  void initState() {
    super.initState();
    setState(() {
      visionSession = widget.visionSession;
      markingSession = widget.markingSession;
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

  void startSessionMarking() {
    setState(() {
      markingSession.start();
    });
  }

  void pauseSessionVision() async {
    const command = 'pause';
    final sent = await sendCommand(command);

    if (sent) {
      awaitCommand(command).then((value) {
        if (value == "PAUSED" && !visionSession.paused) {
          setState(() {
            visionSession.pause();
          });
        } else if (value == "RESUMED" && visionSession.paused) {
          setState(() {
            visionSession.pause();
          });
        }
      });
    }
  }

  void pauseSessionMarking() async {
    const command = "pause";
    final sent = await sendCommand(command);

    if (sent) {
      awaitCommand(command).then((value) {
        if (value == "PAUSED" && !markingSession.paused) {
          setState(() {
            visionSession.pause();
          });
        } else if (value == "RESUMED" && visionSession.paused) {
          setState(() {
            visionSession.pause();
          });
        }
      });
    }
  }

  void homeVision() async {
    const command = 'home';
    final sent = await sendCommand(command);

    if (sent) {
      setState(() {
        homeMessage = 'Homing...';
      });
      awaitCommand(command).then((value) {
        setState(() {
          homeMessage = value;
        });
      });
    }
  }

  void measurePCB() async {
    const command = 'measure_pcb';
    final sent = await sendCommand(command);

    if (sent) {
      setState(() {
        pcbMeasuring = true;
      });
      awaitCommand(command).then((value) {
        setState(() {
          pcbMeasureMessage = value;
          pcbMeasuring = false;
        });
      });
    }
  }

  /// Sends the measure label command to the mcu
  void measureLabel() async {
    const command = "measure_label";
    final sent = await sendCommand(command); // send the command

    if (sent) {
      setState(() {
        labelMeasuring = true;
      });
      awaitCommand(command).then((value) {
        setState(() {
          labelMeasureMessage = value;
          labelMeasuring = false;
        });
      });
    }
  }

  void measureAssembly() async {
    const command = "measure_assembly";
    final sent = await sendCommand(command); // send the command

    if (sent) {
      setState(() {
        assemblyMeasuring = true;
      });

      awaitCommand(command).then((value) {
        setState(() {
          labelMeasureMessage = value;
          labelMeasuring = false;
        });
      });
    }
  }

  void startMarking() async {
    const command = "start_marking";
    final sent = await sendCommand(command);

    if (sent) {
      setState(() {
        isMarking = true;
      });

      awaitCommand(command).then((value) {
        setState(() {
          isMarking = false;
          labelMarking = value;
        });
      });
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

  Future<void> endSessionMarking() async {
    final result = await showConfirmationDialog();

    if (result ?? false) {
      setState(() {
        markingSession.end();
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

  Future<bool> sendCommand(String command) async {
    final response = await controlService.sendCommand(
      type: 'MCU',
      id: visionMcuId!,
      command: command,
    );

    if (response.statusCode == 204) {
      return true;
    }

    log(
      '"$command" command unsuccessful: (${response.statusCode}) ${response.body}',
    );
    return false;
  }

  /// Awaits the command result
  ///
  /// [command] the command string
  Future<String> awaitCommand(String command) async {
    /// the http response from the request
    dynamic response;

    /// the result from querying the map in [response]
    String? result;
    do {
      response = await backendService.incomingRequest;

      /// The result is either 'RECEIVED' or 'BUSY'
      /// Response syntax:
      /// ```json
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
      /// ```

      result = response['data'][0]['${command}_info'];
    } while (result == null);

    if (result == 'RECEIVED') {
      do {
        response = await backendService.incomingRequest;
        result = response['data'][0]['${command}_info'];
      } while (result == null);

      return result;
    }

    return '';
  }

  List<Widget> buildVision(BuildContext context) {
    return [
      const Text(
        "Vision",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
      ),
      const SizedBox(height: 10),
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
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ElevatedButton(
                onPressed: visionSession.started && !visionSession.paused
                    ? homeVision
                    : null,
                child: Container(
                  alignment: Alignment.center,
                  height: rowHeight,
                  child: const Text("Home"),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
              child: Card(
                child: Container(
                  height: rowHeight,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  alignment: Alignment.center,
                  child: Text(homeMessage),
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
                  child: const Text("Measure Label"),
                ),
              ),
            ),
          ),
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
                  child: const Text("Measure Assembly"),
                ),
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
                child: Text(
                  pcbMeasuring ? 'Measuring...' : "PCB: $pcbMeasureMessage",
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                height: rowHeight,
                alignment: Alignment.center,
                child: Text(
                  labelMeasuring
                      ? 'Measuring...'
                      : "Label: $labelMeasureMessage",
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                height: rowHeight,
                alignment: Alignment.center,
                child: Text(
                  assemblyMeasuring
                      ? 'Measuring...'
                      : "Assembly: $assemblyMeasureMessage",
                ),
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
                child: Text("Maintenance in: $maintenanceMessage"),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Builds a list of widgets of the marking UI elements
  List<Widget> buildMarking(BuildContext context) {
    return [
      const Text(
        "Marking",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: ElevatedButton(
                onPressed: !markingSession.started ? startSessionMarking : null,
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
                onPressed: markingSession.started ? pauseSessionMarking : null,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                    Colors.amber.shade300,
                  ),
                ),
                child: Container(
                  height: rowHeight,
                  alignment: Alignment.center,
                  child: Text(markingSession.paused ? "Resume" : "Pause"),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
              child: ElevatedButton(
                onPressed: markingSession.started ? endSessionMarking : null,
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
              padding: const EdgeInsets.fromLTRB(8, 10, 0, 0),
              child: ElevatedButton(
                onPressed: () {},
                child: Container(
                    alignment: Alignment.center,
                    height: rowHeight,
                    child: const Text("Start Marking")),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Card(
                child: Container(
                  height: rowHeight,
                  alignment: Alignment.center,
                  child: Text(
                    isMarking ? "Marking..." : "Marking: $labelMarking",
                  ),
                ),
              ),
            ),
          )
        ],
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...buildVision(context),
        ...buildMarking(context),
      ],
    );
  }
}
