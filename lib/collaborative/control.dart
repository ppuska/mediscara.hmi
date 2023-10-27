import 'dart:async';
import 'dart:io';

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

  /// The row height of the UI elements
  static const double _rowHeight = 100;

  /// The margin between rows
  static const double _rowMargin = 10;

  late Session visionSession;
  late Session markingSession;

  /// Message to be displayed next to the home button
  String homeMessage = '';

  /// Maintenance-related message FIXME: hardcoded message
  String maintenanceMessage = '270 days - Battery Check';

  bool isMarking = false;
  String labelMarking = '';

  bool pcbMeasuring = false;
  String pcbMeasureMessage = "No data";
  bool pcbNoLiftMeasuring = false;
  String pcbNoLiftMeasureMessage = "No data";
  bool assemblyMeasuring = false;
  String assemblyMeasureMessage = "No data";

  /// Sets the default value of the sent robot program
  final String? defaultRobotProgram = dotenv.env['DEFAULT_ROBOT_PROG'];

  /// flag to enable manager services in the code
  final String? useManagerService = dotenv.env["USE_MANAGER"];

  /// Id of the vision MCU in the OCB
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

  /// Gets called when the user presses the 'Start Session' button on the
  /// vision UI
  void startSessionVision() {
    setState(() {
      visionSession.start();
    });
  }

  /// Gets called when the user presses the 'Start Session' button on the
  /// marking UI
  void startSessionMarking() {
    setState(() {
      markingSession.start();
    });
  }

  /// Gets called when the user presses the 'Pause Session' button on the
  /// vision UI
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

  /// Gets called when the user presses the 'Pause Session' button on the
  /// marking UI
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

  /// Gets called when the user presses the 'Home Vision' button
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

  /// Gets called when the user presses the 'Measure PCB' button on the
  /// vision UI
  ///
  /// The method uses the [sendCommand] method to send the specified command.
  /// Then it awaits the command result (http post to the HMI's endpoint
  /// via the OCB subscriptions) via the [awaitCommand] method
  void measurePCB() async {
    const command = 'measure_pcb';
    final sent = await sendCommand(command);

    if (sent) {
      setState(() {
        pcbMeasuring = true;
        pcbMeasureMessage = "Measuring...";
      });
      awaitCommand(command).then((value) {
        setState(() {
          pcbMeasureMessage = value;
          pcbMeasuring = false;
          visionSession.kpi.jobDone(); // TODO delet this
        });
      });
    }
  }

  /// Gets called when the user presses the 'Measure Label' button in the
  /// vision UI
  ///
  /// For more detail check the [measurePCB] methods docs
  void measurePcbNoLift() async {
    const command = "measure_label";
    final sent = await sendCommand(command); // send the command

    if (sent) {
      setState(() {
        pcbNoLiftMeasuring = true;
      });
      awaitCommand(command).then((value) {
        setState(() {
          pcbNoLiftMeasureMessage = value;
          pcbNoLiftMeasuring = false;
        });
      });
    }
  }

  /// Gets called when the user presses the 'Measure Assembly' button in the
  /// vision UI
  ///
  /// For more detail check the [measurePCB] methods docs
  void measureAssembly() async {
    const command = "measure_assembly";
    final sent = await sendCommand(command); // send the command

    if (sent) {
      setState(() {
        assemblyMeasuring = true;
      });

      awaitCommand(command).then((value) {
        setState(() {
          assemblyMeasureMessage = value;
          assemblyMeasuring = false;

          visionSession.kpi.jobDone();
        });
      });
    }
  }

  /// Gets called when the user presses the 'Start marking' button in the
  /// marking UI
  void startMarking() async {
    const command = "start_marking";
    final sent = await sendCommand(command);

    if (sent) {
      setState(() {
        isMarking = true;
      });

      awaitCommand(command).then((value) {
        setState(() {
          stdout.writeln("Marking completed");
          markingSession.kpi.jobDone();
          isMarking = false;
          labelMarking = value;
        });
      });
    }
  }

  /// Gets called when the user presses the 'End Session' button in the
  /// vision UI
  Future<void> endSessionVision() async {
    final result = await showConfirmationDialog();

    if (result ?? false) {
      setState(() {
        visionSession.end();
      });
    }
  }

  /// Gets called when the user presses the 'End Session' button in the
  /// marking UI
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

  /// Sends the given [command] string to the OCB
  ///
  /// If the response's status code is invalid (not 204 - No Content)
  /// then the return value is false
  Future<bool> sendCommand(String command) async {
    final response = await controlService.sendCommand(
      type: 'MCU',
      id: visionMcuId!,
      command: command,
    );

    if (response.statusCode == 204) {
      return true;
    }

    stdout.writeln(
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
      } while (result == null || result == 'RECEIVED' || result == 'BUSY');

      return result;
    }

    return '';
  }

  /// Builds the contents for the vision system UI components
  Widget buildVision(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            "Vision",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:
                    Theme.of(context).textTheme.headline2?.fontSize ?? 32),
          ),
          const SizedBox(height: 2 * _rowMargin),

          /// Buttons
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: ElevatedButton(
                    onPressed:
                        !visionSession.started ? startSessionVision : null,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.lightGreen,
                      ),
                    ),
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        "Start session",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                  child: ElevatedButton(
                    onPressed:
                        visionSession.started ? pauseSessionVision : null,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.amber.shade300,
                      ),
                    ),
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        visionSession.paused ? "Resume" : "Pause",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
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
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        "End session",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _rowMargin),

          /// Home
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
                      height: _rowHeight,
                      child: Text(
                        "Home",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                  child: Card(
                    child: Container(
                      height: _rowHeight,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      alignment: Alignment.center,
                      child: Text(homeMessage),
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 2 * _rowMargin),

          /// Measure
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ElevatedButton(
                    onPressed: visionSession.started &&
                            !visionSession.paused &&
                            !pcbNoLiftMeasuring &&
                            !assemblyMeasuring &&
                            !pcbMeasuring
                        ? measurePCB
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      height: _rowHeight,
                      child: Text(
                        "Measure pcb",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
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
                            !pcbNoLiftMeasuring &&
                            !pcbMeasuring
                        ? measurePcbNoLift
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      height: _rowHeight,
                      child: Text(
                        "Measure PCB (No Lift)",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
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
                            !pcbNoLiftMeasuring &&
                            !assemblyMeasuring &&
                            !pcbMeasuring
                        ? measureAssembly
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      height: _rowHeight,
                      child: Text(
                        "Measure Assembly",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2 * _rowMargin),

          /// Results
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    height: _rowHeight,
                    alignment: Alignment.center,
                    child: Text(
                      pcbMeasuring ? 'Measuring...' : "PCB: $pcbMeasureMessage",
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headline6?.fontSize ??
                                10,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    height: _rowHeight,
                    alignment: Alignment.center,
                    child: Text(
                      pcbNoLiftMeasuring
                          ? 'Measuring...'
                          : "PCB (No Lift): $pcbNoLiftMeasureMessage",
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headline6?.fontSize ??
                                10,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    height: _rowHeight,
                    alignment: Alignment.center,
                    child: Text(
                      assemblyMeasuring
                          ? 'Measuring...'
                          : "Assembly: $assemblyMeasureMessage",
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headline6?.fontSize ??
                                10,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the contents for the marking UI components
  Widget buildMarking(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            "Marking",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:
                    Theme.of(context).textTheme.headline2?.fontSize ?? 32),
          ),
          const SizedBox(height: 2 * _rowMargin),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: ElevatedButton(
                    onPressed:
                        !markingSession.started ? startSessionMarking : null,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.lightGreen,
                      ),
                    ),
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        "Start session",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                  child: ElevatedButton(
                    onPressed:
                        markingSession.started ? pauseSessionMarking : null,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.amber.shade300,
                      ),
                    ),
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        markingSession.paused ? "Resume" : "Pause",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                  child: ElevatedButton(
                    onPressed:
                        markingSession.started ? endSessionMarking : null,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.deepOrange,
                      ),
                    ),
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        "End session",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _rowMargin),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 0, 0),
                  child: ElevatedButton(
                    onPressed: markingSession.started
                        ? startMarking
                        : null, // TODO: implement marking logic
                    child: Container(
                      alignment: Alignment.center,
                      height: _rowHeight,
                      child: Text(
                        "Start Marking",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline3?.fontSize ??
                                  20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                  child: Card(
                    child: Container(
                      height: _rowHeight,
                      alignment: Alignment.center,
                      child: Text(
                        isMarking && labelMarking.isNotEmpty
                            ? "Marking..."
                            : "Marking: $labelMarking",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.headline6?.fontSize ??
                                  10,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildVision(context),
        buildMarking(context),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  height: _rowHeight,
                  alignment: Alignment.center,
                  child: Text(
                    "Maintenance in: $maintenanceMessage",
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.headline4?.fontSize ?? 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
