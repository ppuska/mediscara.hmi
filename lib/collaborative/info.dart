import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hmi_app/models/kpi.dart';
import 'package:hmi_app/services/backend.dart';
import 'package:hmi_app/services/fiware.dart';

class InfoWidget extends StatefulWidget {
  final KPI visionKpi;
  final KPI markingKpi;

  const InfoWidget({
    Key? key,
    required this.visionKpi,
    required this.markingKpi,
  }) : super(key: key);

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> {
  /// [KPI] object for the vision session
  late KPI visionKpi;

  /// [KPI] object for the marking session
  late KPI markingKpi;

  /// [Timer] for the UI update scheduling
  late Timer updateTimer;

  bool visionPower = false;
  bool visionRunning = false;
  bool visionWaiting = false;
  bool visionError = false;

  double visionPerformance = 0;
  double visionAvailability = 0;
  double visionQuality = 0;

  double markingPerformance = 0;
  double markingAvailability = 0;
  double markingQuality = 0;

  final fiwareService = FiwareService();
  final backendService = BackendService();

  final visionMcuId = dotenv.env["INDUSTRIAL_MCU_ID"];

  @override
  void initState() {
    super.initState();

    visionKpi = widget.visionKpi;
    markingKpi = widget.markingKpi;

    updateTimer = Timer.periodic(const Duration(seconds: 1), updateUI);
    updateUI();

    // register callback for status changes
    backendService.registerRSCallback(updateRobotState);
    getRobotState();
  }

  /// Gets called when a new POST arrives at the
  /// /robotStatus endpoint
  ///
  /// This happens whenever the robot statuses get updated from the MCU
  void updateRobotState(Map<String, dynamic>? state) {
    if (state != null) {
      setState(() {
        visionPower = state['robotPower'] as bool;
        visionRunning = state['robotRunning'] as bool;
        visionWaiting = state['robotWaiting'] as bool;
        visionError = state['robotError'] as bool;
      });
    }
  }

  /// Fetches the state of the MCU from the OCB
  void getRobotState() async {
    // get the mcu entity
    final state = await fiwareService.getEntity(
      id: visionMcuId!,
      keyValues: true,
    );

    updateRobotState(state);
  }

  /// Updates the UI KPI elements
  void updateUI([Timer? _]) {
    setState(() {
      /// Calculate vision KPI
      visionAvailability = visionKpi.availability.calculate();
      visionPerformance = visionKpi.performance
          .calculate(visionKpi.availability.actualDuration);
      visionQuality = visionKpi.quality.calculate();

      /// Calculate marking KPI
      markingAvailability = markingKpi.availability.calculate();
      markingPerformance = markingKpi.performance
          .calculate(markingKpi.availability.actualDuration);
      markingQuality = markingKpi.quality.calculate();
    });
  }

  @override
  void dispose() {
    // cancel the ui update timer
    updateTimer.cancel();
    // unregister the callback to the state updates
    backendService.unregisterRSCallback(updateRobotState);
    super.dispose();
  }

  Widget buildVision(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          const Text(
            'Vision',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
                      "Availability ${(visionAvailability * 100).toStringAsFixed(2)} %",
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                    child: Text(
                      "Performance ${(visionPerformance * 100).toStringAsFixed(2)} %",
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                    child: Text(
                      "Quality ${(visionQuality * 100).toStringAsFixed(2)} %",
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            color: visionPower ? Colors.green.shade400 : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: const Center(child: Text("Power")),
            ),
          ),
          Card(
            color: visionRunning ? Colors.yellow.shade300 : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: const Center(child: Text("Running")),
            ),
          ),
          Card(
            color: visionWaiting ? Colors.yellow.shade300 : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: const Center(child: Text("Waiting")),
            ),
          ),
          Card(
            color: visionError ? Colors.deepOrange.shade400 : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: const Center(child: Text("Error")),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMarking(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          const Text(
            'Marking',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
                      "Availability ${(markingAvailability * 100).toStringAsFixed(2)} %",
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                    child: Text(
                      "Performance ${(markingPerformance * 100).toStringAsFixed(2)} %",
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                    child: Text(
                      "Quality ${(markingQuality * 100).toStringAsFixed(2)} %",
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      ],
    );
  }
}
