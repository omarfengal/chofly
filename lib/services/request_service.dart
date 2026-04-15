// lib/services/request_service.dart
// TÂCHE 6 — Refactor: extrait de firebase_service.dart
// Responsabilité: création/gestion des demandes de service

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/result.dart';
import 'firebase_service.dart' show safeFirebase, safeFirebaseVoid;

class RequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<Result<String>> createRequest(ServiceRequest request) async {
    return safeFirebase(() async {
      final id = _uuid.v4();
      final req = ServiceRequest(
        id: id,
        customerId: request.customerId,
        customerName: request.customerName,
        customerPhone: request.customerPhone,
        category: request.category,
        issueType: request.issueType,
        description: request.description,
        photoUrls: request.photoUrls,
        wilaya: request.wilaya,
        commune: request.commune,
        address: request.address,
        location: request.location,
        priceRangeMin: request.priceRangeMin,
        priceRangeMax: request.priceRangeMax,
        createdAt: DateTime.now(),
        needsManualAssignment: true,
      );
      await _db.collection('requests').doc(id).set(req.toFirestore());
      return id;
    });
  }

  Future<Result<String>> uploadPhoto(File file, String requestId) async {
    return safeFirebase(() async {
      final ref = _storage.ref('requests/$requestId/${_uuid.v4()}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    });
  }

  // ── Streams ────────────────────────────────────────────────────
  Stream<ServiceRequest?> getRequest(String requestId) {
    return _db.collection('requests').doc(requestId).snapshots()
        .map((doc) => doc.exists ? ServiceRequest.fromFirestore(doc) : null);
  }

  Stream<List<ServiceRequest>> getCustomerRequests(String customerId) {
    return _db.collection('requests')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(20).snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  Stream<List<ServiceRequest>> getActiveCustomerRequests(String customerId) {
    return _db.collection('requests')
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: ['pending', 'accepted', 'inProgress'])
        .orderBy('createdAt', descending: true).snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  Stream<List<ServiceRequest>> getProviderRequests(String providerId) {
    return _db.collection('requests')
        .where('providerId', isEqualTo: providerId)
        .where('status', whereIn: ['pending', 'accepted', 'inProgress'])
        .orderBy('createdAt', descending: true).snapshots()
        .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  // ── Mutations ──────────────────────────────────────────────────
  Future<Result<void>> acceptRequest(String requestId, String providerId, String providerName) async {
    return safeFirebase(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.accepted.name,
      'providerId': providerId,
      'providerName': providerName,
      'acceptedAt': FieldValue.serverTimestamp(),
      'needsManualAssignment': false,
    }));
  }

  Future<void> rejectRequest(String requestId) async {
    await safeFirebaseVoid(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.rejected.name, 'needsManualAssignment': true,
    }));
  }

  Future<void> startJob(String requestId) async {
    await safeFirebaseVoid(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.inProgress.name,
      'startedAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> completeJob(String requestId, int finalPrice) async {
    await safeFirebaseVoid(() async {
      final batch = _db.batch();
      final reqRef = _db.collection('requests').doc(requestId);
      batch.update(reqRef, {
        'status': RequestStatus.completed.name,
        'finalPrice': finalPrice,
        'completedAt': FieldValue.serverTimestamp(),
      });
      final reqDoc = await reqRef.get();
      final providerId = reqDoc.data()?['providerId'] as String?;
      if (providerId != null) {
        batch.update(_db.collection('providers').doc(providerId), {
          'completedJobs': FieldValue.increment(1),
          'totalEarnings': FieldValue.increment(finalPrice),
        });
      }
      await batch.commit();
    });
  }

  Future<void> cancelRequest(String requestId) async {
    await safeFirebaseVoid(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    }));
  }

  // FIX: Atomic rating — FieldValue.increment évite la race condition
  Future<void> submitReview({
    required String requestId,
    required String customerId,
    required String customerName,
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    await safeFirebaseVoid(() async {
      final batch = _db.batch();
      final reviewRef = _db.collection('reviews').doc();
      final review = ReviewModel(
        id: reviewRef.id, requestId: requestId,
        customerId: customerId, customerName: customerName,
        providerId: providerId, rating: rating,
        comment: comment, createdAt: DateTime.now(),
      );
      batch.set(reviewRef, review.toFirestore());
      batch.update(_db.collection('requests').doc(requestId), {'isRated': true});
      batch.update(_db.collection('providers').doc(providerId), {
        'ratingTotal': FieldValue.increment(rating),
        'ratingCount': FieldValue.increment(1),
      });
      await batch.commit();
    });
  }

  // TÂCHE 2 — Compteur d'artisans disponibles (stream temps réel)
  Stream<int> watchAvailableProviders(String wilaya) {
    return _db.collection('providers')
        .where('isApproved', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .where('wilaya', isEqualTo: wilaya)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // Stream global (toutes wilayas) en fallback
  Stream<int> watchAvailableProvidersGlobal() {
    return _db.collection('providers')
        .where('isApproved', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);
  }
}
