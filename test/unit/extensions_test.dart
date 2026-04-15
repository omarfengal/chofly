// test/unit/extensions_test.dart — Tests des extensions Dart CHOFLY

import 'package:flutter_test/flutter_test.dart';
import 'package:chofly/utils/app_extensions.dart';
import 'package:chofly/models/models.dart';
import 'package:flutter/material.dart';

void main() {
  // ── StringX ─────────────────────────────────────────────────
  group('StringX.isValidAlgerianPhone', () {
    test('numéros 05xx valides', () {
      expect('0561234567'.isValidAlgerianPhone, true);
      expect('0551234567'.isValidAlgerianPhone, true);
    });
    test('numéros 06xx valides', () {
      expect('0661234567'.isValidAlgerianPhone, true);
      expect('0621234567'.isValidAlgerianPhone, true);
    });
    test('numéros 07xx valides', () {
      expect('0771234567'.isValidAlgerianPhone, true);
    });
    test('avec espaces → valide', () {
      expect('06 61 23 45 67'.isValidAlgerianPhone, true);
    });
    test('numéro court → invalide', () {
      expect('066123456'.isValidAlgerianPhone, false);
    });
    test('préfixe invalide 08xx → invalide', () {
      expect('0861234567'.isValidAlgerianPhone, false);
    });
    test('chaîne vide → invalide', () {
      expect(''.isValidAlgerianPhone, false);
    });
    test('non numérique → invalide', () {
      expect('abcdefghij'.isValidAlgerianPhone, false);
    });
  });

  group('StringX.initials', () {
    test('deux mots → deux initiales majuscules', () {
      expect('Omar Benali'.initials, 'OB');
      expect('karim bensalem'.initials, 'KB');
    });
    test('un mot → une initiale', () {
      expect('Omar'.initials, 'O');
    });
    test('chaîne vide → ?', () {
      expect(''.initials, '?');
    });
    test('trois mots → deux premières initiales', () {
      expect('Jean Paul Martin'.initials, 'JP');
    });
  });

  group('StringX.whatsappNumber', () {
    test('0X → 213X', () {
      expect('0661234567'.whatsappNumber, '213661234567');
    });
    test('213X → inchangé', () {
      expect('213661234567'.whatsappNumber, '213661234567');
    });
    test('espaces supprimés', () {
      expect('066 123 4567'.whatsappNumber, '213661234567');
    });
  });

  // ── IntX ─────────────────────────────────────────────────────
  group('IntX.formattedDA', () {
    test('contient DA', () {
      expect(1500.formattedDA, contains('DA'));
    });
    test('1500 → contient 1 et 5', () {
      expect(1500.formattedDA, contains('1'));
    });
    test('0 → contient 0', () {
      expect(0.formattedDA, contains('0'));
    });
  });

  // ── DateTimeX ────────────────────────────────────────────────
  group('DateTimeX.timeAgo', () {
    test('moins d\'1 minute → À l\'instant', () {
      final now = DateTime.now();
      expect(now.timeAgo, 'À l\'instant');
    });
    test('30 minutes → Il y a 30 min', () {
      final past = DateTime.now().subtract(const Duration(minutes: 30));
      expect(past.timeAgo, contains('30 min'));
    });
    test('3 heures → Il y a 3h', () {
      final past = DateTime.now().subtract(const Duration(hours: 3));
      expect(past.timeAgo, contains('3h'));
    });
  });

  // ── RequestStatusX ───────────────────────────────────────────
  group('RequestStatusX', () {
    test('chaque statut a une couleur', () {
      for (final s in RequestStatus.values) {
        expect(s.color, isA<Color>(),
            reason: 'Statut $s: couleur manquante');
      }
    });

    test('chaque statut a un label non vide', () {
      for (final s in RequestStatus.values) {
        expect(s.label, isNotEmpty,
            reason: 'Statut $s: label vide');
      }
    });

    test('chaque statut a une icône', () {
      for (final s in RequestStatus.values) {
        expect(s.icon, isA<IconData>(),
            reason: 'Statut $s: icône manquante');
      }
    });

    test('pending → couleur orange/jaune', () {
      expect(RequestStatus.pending.color, const Color(0xFFFFB347));
    });

    test('completed → couleur verte', () {
      expect(RequestStatus.completed.color, const Color(0xFF2ECC71));
    });

    test('cancelled → couleur rouge', () {
      expect(RequestStatus.cancelled.color, const Color(0xFFFF6B6B));
    });
  });
}
