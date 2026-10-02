import 'package:flutter_test/flutter_test.dart';

import 'package:falcon_intel_mobile/features/alerts/alerts_screen.dart';

void main() {
  test('only unchecked alerts count towards the badge', () {
    final alerts = <Map<String, dynamic>>[
      {'status': 'new'},
      {}, // no status → treated as new
      {'status': 'checked'},
      {'status': 'resolved'},
      {'status': 'investigating'},
    ];
    expect(alerts.where(isOpenAlert).length, 3);
  });
}
