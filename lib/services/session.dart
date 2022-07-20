import 'dart:async';
import 'dart:developer';

import 'package:hmi_app/models/kpi.dart';
import 'package:hmi_app/services/fiware.dart';

class Session {
  bool get started {
    return kpi.started;
  }

  bool get paused {
    return kpi.paused;
  }

  KPI kpi = KPI();
  Timer? kpiTimer;

  Duration updateInterval;
  FiwareService service;

  Session({
    this.updateInterval = const Duration(minutes: 1),
    required this.service,
  });

  void start() {
    kpi.start();
    kpiTimer = Timer.periodic(updateInterval, _sendKPI);
  }

  void pause() {
    kpi.pause();
  }

  void end() {
    kpi.end();
    kpiTimer?.cancel();
  }

  void _sendKPI([Timer? timer]) {
    log("Sending KPI");
    service.sendKPI(kpi);
  }
}
