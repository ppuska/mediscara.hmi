import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/models/kpi.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:hmi_app/services/fiware.dart';

class InfoWidget extends StatefulWidget {
  final KPI kpi;

  const InfoWidget({required this.kpi, Key? key}) : super(key: key);

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> {
  static const double _rowMargin = 10;

  late KPI kpi;

  late Timer updateTimer;

  bool power = false;
  bool running = false;
  bool waiting = false;
  bool error = false;

  double performance = 0;
  double availability = 0;
  double quality = 0;

  final fiwareService = FiwareService();
  final backendService = BackendService();

  final laserMcuId = dotenv.env['INDUSTRIAL_MCU_ID'];

  @override
  void initState() {
    kpi = widget.kpi;
    updateTimer = Timer.periodic(const Duration(seconds: 1), updateUI);

    // register callbacks for the status changes
    backendService.registerRSCallback(updateRobotState);

    // Fetch the initial state manually
    getRobotState();

    super.initState();
  }

  @override
  void dispose() {
    updateTimer.cancel();
    backendService.unregisterRSCallback(updateRobotState);
    super.dispose();
  }

  void updateUI([Timer? _]) {
    setState(() {
      availability = kpi.availability.calculate();
      performance = kpi.performance.calculate(kpi.availability.actualDuration);
      quality = kpi.quality.calculate();
    });
  }

  /// Gets called when a new POST lands at the
  /// /robotStatus endpoint
  ///
  /// Updates the ui accordingly
  void updateRobotState(Map<String, dynamic>? state) {
    if (state != null) {
      setState(() {
        power = state['robotPower'] ?? false;
        running = state['robotRunning'] ?? false;
        waiting = state['robotWaiting'] ?? false;
        error = state['robotError'] ?? false;
      });
    }
  }

  /// Fetches the robot state manually from the OCB
  void getRobotState() async {
    final state =
        await fiwareService.getEntity(id: laserMcuId!, keyValues: true);

    updateRobotState(state);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Industrial',
          style: TextStyle(
              fontSize: Theme.of(context).textTheme.headline1?.fontSize ?? 30,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2 * _rowMargin),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                  child: Text(
                    "Availability ${(availability * 100).toStringAsFixed(2)} %",
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.headline4?.fontSize ?? 15,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                  child: Text(
                    "Performance ${(performance * 100).toStringAsFixed(2)} %",
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.headline4?.fontSize ?? 15,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                  child: Text(
                    "Quality ${(quality * 100).toStringAsFixed(2)} %",
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.headline4?.fontSize ?? 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _rowMargin),
        Card(
          color: power ? Colors.green.shade400 : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Center(
                child: Text(
              "Power",
              style: TextStyle(
                  fontSize:
                      Theme.of(context).textTheme.headline3?.fontSize ?? 20),
            )),
          ),
        ),
        const SizedBox(height: _rowMargin),
        Card(
          color: running ? Colors.yellow.shade300 : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Center(
                child: Text(
              "Running",
              style: TextStyle(
                  fontSize:
                      Theme.of(context).textTheme.headline3?.fontSize ?? 20),
            )),
          ),
        ),
        const SizedBox(height: _rowMargin),
        Card(
          color: waiting ? Colors.yellow.shade300 : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Center(
                child: Text(
              "Waiting",
              style: TextStyle(
                  fontSize:
                      Theme.of(context).textTheme.headline3?.fontSize ?? 20),
            )),
          ),
        ),
        const SizedBox(height: _rowMargin),
        Card(
          color: error ? Colors.deepOrange.shade400 : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Center(
                child: Text(
              "Error",
              style: TextStyle(
                  fontSize:
                      Theme.of(context).textTheme.headline3?.fontSize ?? 20),
            )),
          ),
        ),
      ],
    );
  }
}
