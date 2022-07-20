import 'dart:core';

class KPI {
  late Availability availability;
  late Performance performance;
  late Quality quality;

  bool get paused {
    return performance.isPaused;
  }

  bool started = false;

  KPI({int productQuota = 60}) {
    availability = Availability();
    performance = Performance(productQuota: productQuota);
    quality = Quality(productQuota: productQuota);
  }

  void start() {
    availability.startNow();
    started = true;
  }

  void pause() {
    performance.isPaused ? performance.pauseEnd() : performance.pauseStart();
  }

  void end() {
    if (!performance.isPaused) performance.pauseEnd();

    availability.endNow();
    started = false;
  }

  Map<String, dynamic> toNGSIv2([String? id]) {
    if (id == null) {
      return {
        "availability": availability.toNGSIv2(),
        "performance": performance.toNGSIv2(availability.actualDuration),
        "quality": quality.toNGSIv2(),
      };
    }
    return {
      "id": id,
      "type": "kpi",
      "availability": availability.toNGSIv2(),
      "performance": performance.toNGSIv2(availability.actualDuration),
      "quality": quality.toNGSIv2(),
    };
  }
}

class Availability {
  final plannedDuration = const Duration(hours: 2).inMilliseconds;

  DateTime? _actualStart;
  DateTime? _actualEnd;

  void startNow() {
    _actualStart = DateTime.now();
  }

  void endNow() {
    _actualEnd = DateTime.now();
  }

  int get actualDuration {
    if (_actualEnd == null) {
      return -(_actualStart?.difference(DateTime.now()).inMilliseconds ?? 0);
    }
    return -(_actualStart?.difference(_actualEnd!).inMilliseconds ?? 0);
  }

  double calculate() {
    return actualDuration / plannedDuration;
  }

  Map<String, dynamic> toNGSIv2() {
    return {
      "type": "Number",
      "value": calculate(),
    };
  }
}

class Performance {
  final int productQuota;
  final int workPeriod = const Duration(hours: 10).inMilliseconds;

  late double referencePerformance;
  Duration paused = const Duration(hours: 0);

  DateTime? _pauseStarted;

  int productCount = 0;

  bool get isPaused {
    // it is paused when the start timestap is not null
    return _pauseStarted != null;
  }

  Performance({required this.productQuota}) {
    referencePerformance = workPeriod / productQuota;
  }

  void pauseStart() {
    _pauseStarted = DateTime.now();
  }

  void pauseEnd() {
    if (_pauseStarted == null) return;

    paused = paused +
        Duration(
          milliseconds:
              -_pauseStarted!.difference(DateTime.now()).inMilliseconds,
        );

    _pauseStarted = null;
  }

  /// Calculates the Performance value
  ///
  /// aCurM is the actual duration from the availability class
  double calculate(int aCurM) {
    if (productCount == 0) return 0.0;

    final actualPerformance = (aCurM - paused.inMilliseconds) / productCount;

    return actualPerformance != 0.0
        ? actualPerformance / referencePerformance
        : 0.0;
  }

  Map<String, dynamic> toNGSIv2(int aCurM) {
    return {
      "type": "Number",
      "value": calculate(aCurM),
    };
  }
}

class Quality {
  final int productQuota;

  var productCount = 0;
  var errorCount = 0;

  Quality({required this.productQuota});

  double calculate() {
    return productCount != 0 ? (productCount - errorCount) / productQuota : 0.0;
  }

  Map<String, dynamic> toNGSIv2() {
    return {
      "type": "Number",
      "value": calculate(),
    };
  }
}
