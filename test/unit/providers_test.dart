// test/unit/providers_test.dart — Tests des ChangeNotifiers

import 'package:flutter_test/flutter_test.dart';
import 'package:chofly/services/providers.dart';

void main() {
  // ── RequestProvider ──────────────────────────────────────────
  group('RequestProvider', () {
    test('état initial: isLoading=false, error=null', () {
      final p = RequestProvider();
      expect(p.isLoading, false);
      expect(p.error, isNull);
      expect(p.activeRequestId, isNull);
    });

    test('clearError: réinitialise error', () {
      final p = RequestProvider();
      p.clearError();
      expect(p.error, isNull);
    });
  });

  // ── AuthProvider ─────────────────────────────────────────────
  group('AuthProvider', () {
    test('état initial: pas authentifié', () {
      final p = AuthProvider();
      expect(p.isAuthenticated, false);
      expect(p.isLoading, false);
      expect(p.userModel, isNull);
      expect(p.firebaseUser, isNull);
    });

    test('isCustomer/isProvider/isAdmin: false si userModel null', () {
      final p = AuthProvider();
      expect(p.isCustomer, false);
      expect(p.isProvider, false);
      expect(p.isAdmin, false);
    });

    test('clearError: ne crash pas si error déjà null', () {
      final p = AuthProvider();
      expect(() => p.clearError(), returnsNormally);
    });
  });
}
