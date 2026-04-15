// test/unit/models_test.dart — Tests unitaires des modèles CHOFLY
// Lancer: flutter test test/unit/models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:chofly/models/models.dart';
import 'package:chofly/models/subscription_model.dart';

void main() {
  // ── UserModel ────────────────────────────────────────────────
  group('UserModel', () {
    late FakeFirebaseFirestore fakeFs;

    setUp(() => fakeFs = FakeFirebaseFirestore());

    test('fromFirestore: null-safe sur createdAt absent', () async {
      await fakeFs.collection('users').doc('u1').set({
        'phone': '0661234567', 'name': 'Omar', 'role': 'customer',
      });
      final doc = await fakeFs.collection('users').doc('u1').get();
      expect(() => UserModel.fromFirestore(doc), returnsNormally);
      final u = UserModel.fromFirestore(doc);
      expect(u.createdAt, isA<DateTime>());
    });

    test('fromFirestore: champs complets', () async {
      final now = DateTime(2025, 6, 1, 10, 0);
      await fakeFs.collection('users').doc('u2').set({
        'phone': '0551234567', 'name': 'Karim', 'role': 'provider',
        'isBlocked': false, 'rating': 4.5, 'totalOrders': 12,
        'walletBalance': 1000, 'referralCode': 'CHO-KARIM1',
        'createdAt': Timestamp.fromDate(now),
      });
      final doc = await fakeFs.collection('users').doc('u2').get();
      final u = UserModel.fromFirestore(doc);
      expect(u.name, 'Karim');
      expect(u.role, 'provider');
      expect(u.walletBalance, 1000);
      expect(u.referralCode, 'CHO-KARIM1');
      expect(u.createdAt, now);
    });

    test('copyWith: conserve les champs non modifiés', () {
      final u = UserModel(uid: 'u1', phone: '0661234567', name: 'Omar',
          role: 'customer', rating: 4.2, walletBalance: 500,
          createdAt: DateTime(2025, 1, 1));
      final u2 = u.copyWith(name: 'Omar Benali', walletBalance: 1000);
      expect(u2.name, 'Omar Benali');
      expect(u2.walletBalance, 1000);
      expect(u2.uid, 'u1');
      expect(u2.rating, 4.2);
    });

    test('toFirestore: inclut referralCode et walletBalance', () {
      final u = UserModel(uid: 'u1', phone: '0661234567', name: 'Omar',
          role: 'customer', referralCode: 'CHO-ABC123', walletBalance: 500,
          createdAt: DateTime(2025, 1, 1));
      final map = u.toFirestore();
      expect(map['referralCode'], 'CHO-ABC123');
      expect(map['walletBalance'], 500);
    });
  });

  // ── ProviderModel ────────────────────────────────────────────
  group('ProviderModel', () {
    test('averageRating: calcul correct', () {
      final p = ProviderModel(uid: 'p1', name: 'Y', phone: '0771234567',
          skills: ['plumbing'], wilaya: 'Alger', commune: 'Bab El Oued',
          ratingTotal: 42, ratingCount: 10, createdAt: DateTime(2025, 1, 1));
      expect(p.averageRating, closeTo(4.2, 0.001));
    });

    test('averageRating: fallback sur rating si count=0', () {
      final p = ProviderModel(uid: 'p2', name: 'A', phone: '0551234567',
          skills: ['electricity'], wilaya: 'Oran', commune: 'Bir El Djir',
          rating: 3.5, ratingTotal: 0, ratingCount: 0,
          createdAt: DateTime(2025, 1, 1));
      expect(p.averageRating, 3.5);
    });

    test('fromFirestore: null-safe sur createdAt', () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('providers').doc('p3').set({
        'name': 'Test', 'phone': '0661234567',
        'skills': ['ac'], 'wilaya': 'Alger', 'commune': 'Alger Centre',
      });
      final doc = await fakeFs.collection('providers').doc('p3').get();
      expect(() => ProviderModel.fromFirestore(doc), returnsNormally);
    });
  });

  // ── ServiceRequest ───────────────────────────────────────────
  group('ServiceRequest', () {
    test('fromFirestore: null-safe sur toutes les dates', () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('requests').doc('r1').set({
        'customerId': 'u1', 'customerName': 'Omar',
        'customerPhone': '0661234567', 'category': 'plumbing',
        'issueType': 'Fuite', 'description': 'Fuite cuisine',
        'wilaya': 'Alger', 'commune': 'Bab El Oued', 'address': '5 rue test',
        'status': 'pending', 'priceRangeMin': 1500, 'priceRangeMax': 5000,
        // Aucune date intentionnellement
      });
      final doc = await fakeFs.collection('requests').doc('r1').get();
      expect(() => ServiceRequest.fromFirestore(doc), returnsNormally);
      final r = ServiceRequest.fromFirestore(doc);
      expect(r.category, ServiceCategory.plumbing);
      expect(r.status, RequestStatus.pending);
      expect(r.createdAt, isA<DateTime>());
      expect(r.acceptedAt, isNull);
      expect(r.completedAt, isNull);
    });

    test('fromFirestore: priceRange supporte int et string', () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('requests').doc('r2').set({
        'customerId': 'u1', 'customerName': 'T', 'customerPhone': '066',
        'category': 'electricity', 'issueType': 'P', 'description': 'P',
        'wilaya': 'A', 'commune': 'A', 'address': 'A',
        'status': 'pending',
        'priceRangeMin': '1000', // string — migration legacy
        'priceRangeMax': '4000',
      });
      final doc = await fakeFs.collection('requests').doc('r2').get();
      final r = ServiceRequest.fromFirestore(doc);
      expect(r.priceRangeMin, 1000);
      expect(r.priceRangeMax, 4000);
    });

    test('categoryLabel: toutes les catégories ont un label', () {
      for (final cat in ServiceCategory.values) {
        final r = ServiceRequest(
          id: 'x', customerId: 'u', customerName: 'T', customerPhone: '0',
          category: cat, issueType: 'I', description: 'D',
          wilaya: 'W', commune: 'C', address: 'A',
          priceRangeMin: 0, priceRangeMax: 0, createdAt: DateTime.now(),
        );
        expect(r.categoryLabel, isNotEmpty, reason: 'Catégorie $cat sans label');
      }
    });
  });

  // ── SubscriptionModel ────────────────────────────────────────
  group('SubscriptionModel', () {
    test('fromFirestore: id depuis doc.id, pas du data', () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('subscriptions').doc('sub_abc123').set({
        'customerId': 'u1', 'customerName': 'Omar',
        'plan': 'basic', 'status': 'active',
        'startDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'nextBillingDate': Timestamp.fromDate(DateTime(2025, 2, 1)),
        'monthlyPrice': 1500, 'isPriorityAccess': false,
      });
      final doc = await fakeFs.collection('subscriptions').doc('sub_abc123').get();
      final sub = SubscriptionModel.fromFirestore(doc);
      expect(sub.id, 'sub_abc123');
      expect(sub.isActive, true);
      expect(sub.planName, 'Foyer Essentiel');
      expect(sub.discountPercent, 10);
      expect(sub.monthlyVisits, 1);
    });

    test('fromFirestore: null-safe sur les dates', () async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('subscriptions').doc('sub_test').set({
        'customerId': 'u1', 'customerName': 'T',
        'plan': 'premium', 'status': 'active',
        'monthlyPrice': 2500, 'isPriorityAccess': true,
      });
      final doc = await fakeFs.collection('subscriptions').doc('sub_test').get();
      expect(() => SubscriptionModel.fromFirestore(doc), returnsNormally);
    });

    test('plans: cohérence des données', () {
      expect(SubscriptionModel.plans[SubscriptionPlan.basic]!['price'], 1500);
      expect(SubscriptionModel.plans[SubscriptionPlan.premium]!['price'], 2500);
      expect(SubscriptionModel.plans[SubscriptionPlan.premium]!['priority'], true);
      expect(SubscriptionModel.plans[SubscriptionPlan.basic]!['priority'], false);
    });
  });

  // ── PromoCode ────────────────────────────────────────────────
  group('PromoCode', () {
    test('isValid: false si usageCount >= usageLimit', () {
      final promo = PromoCode(
        id: 'p1', code: 'TEST10', description: 'Test',
        discountPercent: 10, usageLimit: 100, usageCount: 100,
        isActive: true, expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(), createdByAdmin: 'admin',
      );
      expect(promo.isValid, false);
    });

    test('isValid: false si expiré', () {
      final promo = PromoCode(
        id: 'p2', code: 'EXPIRE', description: 'Expiré',
        discountPercent: 20, usageLimit: 100, usageCount: 5,
        isActive: true, expiresAt: DateTime(2020, 1, 1),
        createdAt: DateTime(2019, 1, 1), createdByAdmin: 'admin',
      );
      expect(promo.isValid, false);
    });

    test('isValid: false si isActive=false', () {
      final promo = PromoCode(
        id: 'p3', code: 'INACTIVE', description: 'Inactif',
        discountPercent: 15, usageLimit: 100, usageCount: 0,
        isActive: false, expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(), createdByAdmin: 'admin',
      );
      expect(promo.isValid, false);
    });

    test('discountAmount: percent correct', () {
      final promo = PromoCode(
        id: 'p4', code: 'VALID15', description: '15%',
        discountPercent: 15, usageLimit: 100, usageCount: 0,
        isActive: true, expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(), createdByAdmin: 'admin',
      );
      expect(promo.discountAmount(2000), 300); // 15% de 2000
    });

    test('discountAmount: fixed prioritaire sur percent', () {
      final promo = PromoCode(
        id: 'p5', code: 'FIXED500', description: '500 DA',
        discountPercent: 10, discountFixed: 500, usageLimit: 100, usageCount: 0,
        isActive: true, expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(), createdByAdmin: 'admin',
      );
      expect(promo.discountAmount(2000), 500);
    });

    test('discountAmount: fixed clamped au prix total', () {
      final promo = PromoCode(
        id: 'p6', code: 'OVER', description: 'Over',
        discountPercent: 0, discountFixed: 5000, usageLimit: 10, usageCount: 0,
        isActive: true, expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(), createdByAdmin: 'admin',
      );
      expect(promo.discountAmount(1000), 1000); // clamp(0, 1000)
    });
  });

  // ── ServiceData ──────────────────────────────────────────────
  group('ServiceData', () {
    test('toutes les catégories ont icon, label, issues, priceMin, priceMax', () {
      for (final cat in ServiceCategory.values) {
        final data = ServiceData.categories[cat];
        expect(data, isNotNull, reason: 'Catégorie $cat manquante');
        expect(data!['icon'], isA<String>(), reason: '$cat: icon manquant');
        expect(data['label'], isA<String>(), reason: '$cat: label manquant');
        expect((data['issues'] as List).isNotEmpty, true, reason: '$cat: issues vide');
        expect(data['priceMax'] as int > data['priceMin'] as int, true,
            reason: '$cat: priceMax <= priceMin');
      }
    });

    test('wilayas: non vide, sans doublons', () {
      expect(ServiceData.wilayas.isNotEmpty, true);
      expect(ServiceData.wilayas.length, ServiceData.wilayas.toSet().length,
          reason: 'Doublons détectés dans wilayas');
    });
  });
}
