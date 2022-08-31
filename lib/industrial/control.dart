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

  final double _rowHeight = 80;
  late Session _laserSession;

  final laserMcuId = dotenv.env['LASER_MCU_ID'];

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
  void laserSessionPause() {
    setState(() {
      _laserSession.pause();
    });
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
  void homeLaser() {}

  /// Starts the laser cutting process
  void laserCutStart() async {
    String result;
    final sent = await sendLaserCutStart(); // send the command

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
      result = response['data'][0]['start_laser_cut_info']["value"]!;

      log('Laser cutting result: $result');

      if (result == 'RECEIVED') {
        response = await backendService.incomingRequest;
        result = response['data'][0]['start_laser_cut_info']['value'];

        log('Laser cutting operation result: $result');
      }
    }
  }

  /// Sends the start_laser_cut command to the IoT Agent
  Future<bool> sendLaserCutStart() async {
    final response = await controlService.sendCommand(
      type: 'MCU',
      id: laserMcuId!,
      command: 'start_laser_cut',
    );

    if (response.statusCode == 204) {
      return true;
    }

    log(
      'Start laser cut command unsuccessful: (${response.statusCode}) ${response.body}',
    );
    return false;
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
          "Laser",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(
          height: 10,
        ),
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
                    child: const Text("Start session"),
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
                    child: Text(_laserSession.paused ? "Resume" : "Pause"),
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
                    child: const Text("End session"),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                    child: const Text("Home"),
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
                    child: const Text("Placeholder"),
                  ),
                ),
              )
            ],
          ),
        ),
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
                    child: const Text("Start cutting"),
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
