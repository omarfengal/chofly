// test/all_tests.dart — Lance tous les tests CHOFLY
// Usage: flutter test test/all_tests.dart

import 'unit/models_test.dart' as models;
import 'unit/extensions_test.dart' as extensions;
import 'unit/providers_test.dart' as providers;
import 'unit/services_test.dart' as services;
import 'unit/connectivity_test.dart' as connectivity;
import 'widget/common_widgets_test.dart' as widgets;

void main() {
  models.main();
  extensions.main();
  providers.main();
  services.main();
  connectivity.main();
  widgets.main();
}
