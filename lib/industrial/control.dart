import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:hmi_app/services/fiware.dart';
import 'package:hmi_app/services/session.dart';

class ControlWidget extends StatefulWidget {
  final Session laserSession;

  const ControlWidget({required this.laserSession, Key? key}) : super(key: key);

  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  final controlService = FiwareService();
  final backendService = BackendService();

  static const double _rowHeight = 100;
  static const double _rowMargin = 10;

  /// A [Session] object that is shared between widgets
  late Session _laserSession;

  /// the id of the MCU entity in the OCB
  final laserMcuId = dotenv.env['INDUSTRIAL_MCU_ID'];

  /// the message to be displayed next to the HOME button
  String _homingMessage = '';

  @override
  void initState() {
    super.initState();
    setState(() {
      _laserSession = widget.laserSession;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Gets called when the user clicks the start session button
  void laserSessionStart() {
    setState(() {
      _laserSession.start();
    });
  }

  /// Gets called when the user clicks the pause button
  void laserSessionPause() async {
    const command = 'pause';
    final sent = await sendCommand(command);

    if (sent) {
      awaitCommand(command).then((value) {
        if (value == "PAUSED" && !_laserSession.paused) {
          setState(() {
            _laserSession.pause();
          });
        } else if (value == "RESUMED" && _laserSession.paused) {
          setState(() {
            _laserSession.pause();
          });
        }
      });
    }
  }

  /// Gets called when the user clicks the end session button
  void laserSessionEnd() async {
    final result = await showConfirmationDialog();

    if (result ?? false) {
      setState(() {
        _laserSession.end();
      });
    }
  }

  /// Sends the home laser command to the MCU
  void homeLaser() async {
    setState(() {
      _homingMessage = "Homing...";
    });
    final sent = await sendCommand("home");

    if (sent) {
      awaitCommand('home').then((value) {
        setState(() {
          _homingMessage = value;

          /// TODO add additional wait time
        });
      });
    }
  }

  /// Starts the laser cutting process
  void laserCutStart() async {
    final sent = await sendCommand('start_laser_cut'); // send the command

    if (sent) {
      awaitCommand('start_laser_cut').then((value) {
        _laserSession.kpi.jobDone();
        log("Laser cut result: $value");
      });
    }
  }

  Future<bool> sendCommand(String command) async {
    final response = await controlService.sendCommand(
      type: 'MCU',
      id: laserMcuId!,
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

    if (result == 'RECEIVED' || result == 'BUSY') {
      do {
        response = await backendService.incomingRequest;
        result = response['data'][0]['${command}_info'];
      } while (result == null || result == 'RECEIVED' || result == 'BUSY');

      return result;
    }

    return '';
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
        Text(
          "Laser",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: Theme.of(context).textTheme.headline1?.fontSize ?? 30),
        ),
        const SizedBox(height: 2 * _rowMargin),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: !_laserSession.started ? laserSessionStart : null,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.lightGreen),
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
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: _laserSession.started ? laserSessionPause : null,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.amber.shade300),
                  ),
                  child: Container(
                    height: _rowHeight,
                    alignment: Alignment.center,
                    child: Text(
                      _laserSession.paused ? "Resume" : "Pause",
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headline3?.fontSize ??
                                20,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: _laserSession.started ? laserSessionEnd : null,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.deepOrange),
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
            ],
          ),
        ),
        const SizedBox(height: _rowMargin),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _laserSession.started && !_laserSession.paused
                      ? homeLaser
                      : null,
                  child: Container(
                    height: _rowHeight,
                    alignment: Alignment.center,
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
              const SizedBox(
                width: 8,
              ),
              Expanded(
                flex: 2,
                child: Card(
                  child: Container(
                    alignment: Alignment.center,
                    height: _rowHeight,
                    child: Text(_homingMessage),
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: _rowMargin),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _laserSession.started && !_laserSession.paused
                      ? laserCutStart
                      : null,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.lightBlue),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    height: _rowHeight,
                    child: Text(
                      "Start cutting",
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headline3?.fontSize ??
                                20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
