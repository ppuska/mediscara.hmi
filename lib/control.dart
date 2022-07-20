import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
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
  Timer? kpiTimer;

  final controlService = FiwareService();

  final double rowHeight = 80;
  late Session visionSession;

  bool pcbMeasuring = false;
  String pcbConnectionMessage = "No result";
  String pcbMeasureMessage = "No data";
  bool labelMeasuring = false;
  String labelConnectionMessage = "No result";
  String labelMeasureMessage = "No data";

  @override
  void initState() {
    super.initState();
    setState(() {
      visionSession = widget.visionSession;
    });
  }

  @override
  void dispose() {
    kpiTimer?.cancel();
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
    controlService.sendHome().then(
          (value) => log(
            "Homing command was ${value ? 'successful' : 'unsuccessful'}",
          ),
        );
  }

  void measurePCB() async {
    String? result;
    final sent = await controlService.sendMeasurePCB();
    if (sent) {
      result = await controlService.lastCommandResult;
    } else {
      setState(() {
        pcbConnectionMessage = "Unable to send command to device";
      });
    }

    setState(() {
      pcbConnectionMessage = result ?? "Unknown error";
    });
  }

  /// Sends the measure label command to the mcu
  ///
  /// After the command has been sent, it checks the command result (wether the
  /// mcu processed the command or not)
  /// Finally it starts to poll the MCU's property in the OCB until it has a
  /// modification date newer than when this command was sent
  void measureLabel() async {
    String? result;
    final sentAt = DateTime.now(); // store the time of the command
    final sent = await controlService.sendMeasureLabel(); // send the command

    if (sent) {
      result = await controlService.lastCommandResult;

      setState(() {
        labelConnectionMessage = result ?? "Unknown error";
        labelMeasuring = true;
      });

      // start polling for the measurement result
      // poll until:
      //    the measurement is received
      //    the end session button is pressed
      //
      while (labelMeasuring && visionSession.started) {
        await Future.delayed(const Duration(seconds: 1)); //'sleep' for 1 second
        final measurementResult = await controlService.getMeasurementResult();
        final measurementMessage = measurementResult["value"];
        final resultTime = DateTime.parse(
            measurementResult["metadata"]["TimeInstant"]["value"]);

        if (sentAt.isBefore(resultTime)) {
          log("Got measurement data");
          setState(() {
            labelMeasureMessage = measurementMessage;
            labelMeasuring = false;
          });
        }
      }
    } else {
      setState(() {
        labelConnectionMessage = "Unable to send command to device";
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
      kpiTimer?.cancel();
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
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Column(
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
                          onPressed: !visionSession.started
                              ? startSessionVision
                              : null,
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
                          onPressed:
                              visionSession.started ? pauseSessionVision : null,
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                              Colors.amber.shade300,
                            ),
                          ),
                          child: Container(
                            height: rowHeight,
                            alignment: Alignment.center,
                            child:
                                Text(visionSession.paused ? "Resume" : "Pause"),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                        child: ElevatedButton(
                          onPressed:
                              visionSession.started ? endSessionVision : null,
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
                          onPressed:
                              visionSession.started && !visionSession.paused
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
                          onPressed:
                              visionSession.started && !visionSession.paused
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
                          onPressed:
                              visionSession.started && !visionSession.paused
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
              ],
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Column(
              children: [
                const Text(
                  "Marking",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
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
}
