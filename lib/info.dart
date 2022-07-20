import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hmi_app/models/kpi.dart';

class InfoWidget extends StatefulWidget {
  final KPI visionKpi;

  const InfoWidget({Key? key, required this.visionKpi}) : super(key: key);

  @override
  State<InfoWidget> createState() => _InfoWidgetState();
}

class _InfoWidgetState extends State<InfoWidget> {
  late KPI visionKpi;

  late Timer updateTimer;

  bool visionPower = false;
  bool visionRunning = false;
  bool visionWaiting = false;
  bool visionError = false;

  double visionPerformance = 0;
  double visionAvailability = 0;
  double visionQuality = 0;

  @override
  void initState() {
    super.initState();
    visionKpi = widget.visionKpi;
    updateTimer = Timer.periodic(const Duration(seconds: 1), updateUI);
    updateUI();
  }

  void updateUI([Timer? _]) {
    setState(() {
      visionAvailability = visionKpi.availability.calculate();
      visionPerformance = visionKpi.performance
          .calculate(visionKpi.availability.actualDuration);
      visionQuality = visionKpi.quality.calculate();
    });
  }

  @override
  void dispose() {
    updateTimer.cancel();
    super.dispose();
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
                  'Vision',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                        child: Text(
                          "Availability ${(visionAvailability * 100).toStringAsFixed(2)} %",
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                        child: Text(
                          "Performance ${(visionPerformance * 100).toStringAsFixed(2)} %",
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
                        child: Text(
                          "Quality ${(visionQuality * 100).toStringAsFixed(2)} %",
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  color: visionPower ? Colors.green.shade400 : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 16),
                    child: const Text("Power"),
                  ),
                ),
                Card(
                  color: visionRunning ? Colors.yellow.shade300 : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 16),
                    child: const Text("Running"),
                  ),
                ),
                Card(
                  color: visionWaiting ? Colors.yellow.shade300 : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 16),
                    child: const Text("Waiting"),
                  ),
                ),
                Card(
                  color: visionError ? Colors.deepOrange.shade400 : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 16),
                    child: const Text("Error"),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Column(children: const [
              Text(
                'Marking',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
