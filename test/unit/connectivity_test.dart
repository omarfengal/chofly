// test/unit/connectivity_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chofly/utils/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('singleton: toujours la même instance', () {
      final a = ConnectivityService.instance;
      final b = ConnectivityService.instance;
      expect(identical(a, b), true);
    });

    test('isOnline: true par défaut avant initialisation', () {
      expect(ConnectivityService.instance.isOnline, true);
    });
  });
}
