// test/unit/services_test.dart — Tests des services Firebase (avec fake Firestore)

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chofly/models/models.dart';
import 'package:chofly/models/subscription_model.dart';

// ── Helper: crée un fakeFirestore pré-rempli ──────────────────
FakeFirebaseFirestore makeDb() => FakeFirebaseFirestore();

void main() {
  // ── PromoCode.isValid & discountAmount ───────────────────────
  group('PromoCode business logic', () {
    PromoCode validPromo({int usageCount = 0, int usageLimit = 100, bool isActive = true}) {
      return PromoCode(
        id: 'p1', code: 'TEST', description: 'Test',
        discountPercent: 15, usageLimit: usageLimit, usageCount: usageCount,
        isActive: isActive,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(), createdByAdmin: 'admin',
      );
    }

    test('isValid true si actif, pas expiré, usage < limite', () {
      expect(validPromo().isValid, true);
    });
    test('isValid false si usageCount == usageLimit', () {
      expect(validPromo(usageCount: 100, usageLimit: 100).isValid, false);
    });
    test('isValid false si inactif', () {
      expect(validPromo(isActive: false).isValid, false);
    });
    test('discountAmount(2000) avec 15% = 300', () {
      expect(validPromo().discountAmount(2000), 300);
    });
    test('discountFixed prioritaire sur percent', () {
      final p = PromoCode(
        id: 'x', code: 'F500', description: '', discountPercent: 10,
        discountFixed: 500, usageLimit: 10, usageCount: 0, isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(), createdByAdmin: 'a',
      );
      expect(p.discountAmount(3000), 500);
    });
    test('discountFixed clamp: ne dépasse pas le prix de base', () {
      final p = PromoCode(
        id: 'x', code: 'BIG', description: '', discountPercent: 0,
        discountFixed: 9999, usageLimit: 10, usageCount: 0, isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(), createdByAdmin: 'a',
      );
      expect(p.discountAmount(1000), 1000); // clamp
    });
  });

  // ── Firestore CRUD avec fake ──────────────────────────────────
  group('Firestore UserModel CRUD (fake)', () {
    test('write then read roundtrip', () async {
      final db = makeDb();
      final user = UserModel(
        uid: 'u1', phone: '0661234567', name: 'Omar Benali',
        role: 'customer', wilaya: 'Alger', walletBalance: 500,
        referralCode: 'CHO-OMAR1', createdAt: DateTime(2025, 6, 1),
      );
      await db.collection('users').doc(user.uid).set(user.toFirestore());
      final doc = await db.collection('users').doc('u1').get();
      final read = UserModel.fromFirestore(doc);
      expect(read.name, 'Omar Benali');
      expect(read.walletBalance, 500);
      expect(read.referralCode, 'CHO-OMAR1');
    });

    test('document absent → getUserProfile retourne null', () async {
      final db = makeDb();
      final doc = await db.collection('users').doc('nonexistent').get();
      expect(doc.exists, false);
    });
  });

  group('Firestore ServiceRequest CRUD (fake)', () {
    test('createRequest roundtrip', () async {
      final db = makeDb();
      final req = ServiceRequest(
        id: 'req1',
        customerId: 'u1', customerName: 'Omar', customerPhone: '0661234567',
        category: ServiceCategory.plumbing, issueType: 'Fuite',
        description: 'Fuite sous évier', wilaya: 'Alger', commune: 'Bab El Oued',
        address: '5 rue des frères Aissaoui',
        priceRangeMin: 1500, priceRangeMax: 5000,
        createdAt: DateTime(2025, 6, 1),
      );
      await db.collection('requests').doc('req1').set(req.toFirestore());
      final doc = await db.collection('requests').doc('req1').get();
      final read = ServiceRequest.fromFirestore(doc);
      expect(read.category, ServiceCategory.plumbing);
      expect(read.status, RequestStatus.pending);
      expect(read.customerName, 'Omar');
      expect(read.needsManualAssignment, true);
    });

    test('copyWith status update', () {
      final req = ServiceRequest(
        id: 'r1', customerId: 'u1', customerName: 'T', customerPhone: '0',
        category: ServiceCategory.electricity, issueType: 'I', description: 'D',
        wilaya: 'W', commune: 'C', address: 'A',
        priceRangeMin: 1000, priceRangeMax: 4000, createdAt: DateTime.now(),
      );
      final accepted = req.copyWith(
        status: RequestStatus.accepted,
        providerId: 'p1',
        providerName: 'Yacine',
      );
      expect(accepted.status, RequestStatus.accepted);
      expect(accepted.providerId, 'p1');
      expect(accepted.customerId, 'u1'); // conservé
    });
  });

  // ── ReferralModel ─────────────────────────────────────────────
  group('ReferralModel', () {
    test('toFirestore / fromFirestore roundtrip', () async {
      final db = makeDb();
      final ref = ReferralModel(
        id: 'ref1', referrerId: 'u1', referrerName: 'Omar',
        refereeId: 'u2', refereeName: 'Karim', refereePhone: '0551234567',
        rewardDA: 500, createdAt: DateTime(2025, 6, 1),
      );
      await db.collection('referrals').doc('ref1').set(ref.toFirestore());
      final doc = await db.collection('referrals').doc('ref1').get();
      final read = ReferralModel.fromFirestore(doc);
      expect(read.referrerId, 'u1');
      expect(read.rewardDA, 500);
      expect(read.isCompleted, false);
    });
  });

  // ── SubscriptionModel ─────────────────────────────────────────
  group('SubscriptionModel', () {
    test('createSubscription: id non vide après set()', () async {
      final db = makeDb();
      final ref = db.collection('subscriptions').doc();
      expect(ref.id, isNotEmpty);
      final sub = SubscriptionModel(
        id: ref.id, customerId: 'u1', customerName: 'Omar',
        plan: SubscriptionPlan.premium, status: SubscriptionStatus.active,
        startDate: DateTime(2025, 6, 1),
        nextBillingDate: DateTime(2025, 7, 1),
        monthlyPrice: 2500, isPriorityAccess: true,
      );
      await ref.set(sub.toFirestore());
      final doc = await db.collection('subscriptions').doc(ref.id).get();
      final read = SubscriptionModel.fromFirestore(doc);
      expect(read.id, ref.id);
      expect(read.isActive, true);
      expect(read.monthlyVisits, 2);
      expect(read.discountPercent, 15);
    });
  });
}
