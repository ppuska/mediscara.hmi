import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_app/models/kpi.dart';

void main() {
  group("KPI testing", () {
    final kpi = KPI();

    test('Availability should be 0', () {
      expect(kpi.availability.calculate(), 0);
    });

    test('NGSIv2 formatting', () {
      final map = kpi.toNGSIv2("kpi.test");

      final expected = {
        "id": "kpi.test",
        "type": "kpi",
        "availability": {
          "type": "Number",
          "value": 0.0,
        },
        "performance": {
          "type": "Number",
          "value": 0.0,
        },
        "quality": {
          "type": "Number",
          "value": 0.0,
        },
      };

      expect(map, expected);
    });
  });
}
