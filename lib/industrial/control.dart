import 'dart:io';

import 'dart:async';

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
  final progDescriptorId = dotenv.env['RS_PROG_DESCRIPTOR_ID'];

  /// the message to be displayed next to the HOME button
  String _homingMessage = '';

  static const programSelectorDefaultValue = "Select Program";

  List<String> _programList = [programSelectorDefaultValue];
  String _selectedProgram = programSelectorDefaultValue;
  String? _programSelectorErrorMessage;

  @override
  initState() {
    super.initState();
    setState(() {
      _laserSession = widget.laserSession;
    });

    getProgDescriptor().then(((value) => null));
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> getProgDescriptor() async {
    final progDescriptor =
        await controlService.getEntity(id: progDescriptorId!);

    if (progDescriptor == null) {
      stderr.writeln("Unable to fetch program data");
      return;
    }

    setState(() {
      _programList = [
        programSelectorDefaultValue,
        ...progDescriptor["programs"]["value"]
      ];
    });

    stdout.writeln("RS Program descriptor: $_programList");
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
        });
      });
    }
  }

  /// Starts the laser cutting process
  void laserCutStart() async {
    if (_selectedProgram == programSelectorDefaultValue) {
      stdout.writeln("No program selected yet");
      // display the error
      setState(() {
        _programSelectorErrorMessage = "Please select a program";
      });
      return;
    }

    setState(() {
      stdout.writeln("Program selected: $_selectedProgram");
      _programSelectorErrorMessage = null;
    });

    final sent = await sendCommand(
      'start_laser_cut',
      commandValue: _selectedProgram,
    ); // send the command

    if (sent) {
      awaitCommand('start_laser_cut').then((value) {
        _laserSession.kpi.jobDone();
        stdout.writeln("Laser cut result: $value");
      });
    }
  }

  Future<bool> sendCommand(String command, {dynamic commandValue}) async {
    final response = await controlService.sendCommand(
      type: 'MCU',
      id: laserMcuId!,
      command: command,
      commandValue: commandValue,
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
        // ROW 1
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
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
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
                                  20),
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
              DropdownMenu<String>(
                initialSelection: _programList.first,
                label: const Text("Robot Program"),
                width: 6.3 * _rowHeight,
                onSelected: (String? value) =>
                    _selectedProgram = value ?? programSelectorDefaultValue,
                leadingIcon: const Icon(Icons.document_scanner),
                textStyle: TextStyle(
                    fontSize:
                        Theme.of(context).textTheme.headline3?.fontSize ?? 20),
                dropdownMenuEntries:
                    _programList.map<DropdownMenuEntry<String>>((item) {
                  return DropdownMenuEntry<String>(
                    value: item,
                    label: item,
                  );
                }).toList(),
                inputDecorationTheme: const InputDecorationTheme(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(32))),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: _rowHeight / 3),
                ),
                errorText: _programSelectorErrorMessage,
              ),
              const SizedBox(width: _rowMargin),
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
                                  20),
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
