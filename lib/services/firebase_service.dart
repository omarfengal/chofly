import 'dart:io';
import 'dart:typed_data';
import '../utils/result.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../models/subscription_model.dart';

// ── Safe Firebase call wrapper ────────────────────────────────
// P3: Retourne Result<T> au lieu de T? pour propager les erreurs typées.
// L'ancienne signature T? est conservée via safeFirebaseLegacy pour
// les appels void qui n'ont pas besoin du type d'erreur.
Future<Result<T>> safeFirebase<T>(Future<T> Function() call) async {
  try {
    final value = await call();
    return Success(value);
  } on FirebaseException catch (e) {
    FirebaseCrashlytics.instance.recordError(
      e, e.stackTrace,
      reason: 'FirebaseException: ${e.code}',
      fatal: false,
    );
    final code = switch (e.code) {
      'not-found'              => AppErrorCode.notFound,
      'permission-denied'      => AppErrorCode.permission,
      'already-exists'         => AppErrorCode.alreadyTaken,
      'unauthenticated'        => AppErrorCode.sessionExpired,
      _                        => AppErrorCode.unknown,
    };
    return Failure(code, code.defaultMessage, cause: e);
  } on SocketException catch (e) {
    FirebaseCrashlytics.instance.recordError(
      e, StackTrace.current,
      reason: 'Network error — no internet',
      fatal: false,
    );
    return Failure(AppErrorCode.network, AppErrorCode.network.defaultMessage, cause: e);
  } catch (e, stack) {
    FirebaseCrashlytics.instance.recordError(
      e, stack,
      reason: 'Unexpected error in safeFirebase',
      fatal: false,
    );
    return Failure(AppErrorCode.unknown, AppErrorCode.unknown.defaultMessage, cause: e);
  }
}

// Wrapper pour les appels void ou les anciens callers — retourne bool succès.
Future<bool> safeFirebaseVoid(Future<void> Function() call) async {
  final result = await safeFirebase<void>(() async => await call());
  return result.isSuccess;
}

// ════════════════════════════════════════════════════════════════
// AUTH SERVICE
// ════════════════════════════════════════════════════════════════
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _verificationId;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Vérification échouée');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<UserCredential?> verifyOTP(String smsCode) async {
    if (_verificationId == null) return null;
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();

  /// Supprime le compte Auth + toutes les données Firestore de l'utilisateur.
  /// Doit être appelé en dernier (après nettoyage Firestore) car
  /// la suppression Auth révoque immédiatement la session.
  Future<void> deleteAccount(String uid) async {
    await safeFirebase(() async {
      final db = _db;
      final batch = db.batch();

      // 1. Profil utilisateur
      batch.delete(db.collection('users').doc(uid));

      // 2. Demandes en tant que client
      final requests = await db
          .collection('requests')
          .where('customerId', isEqualTo: uid)
          .get();
      for (final d in requests.docs) batch.delete(d.reference);

      // 3. Abonnements
      final subs = await db
          .collection('subscriptions')
          .where('customerId', isEqualTo: uid)
          .get();
      for (final d in subs.docs) batch.delete(d.reference);

      // 4. Tokens de parrainage
      final refs = await db
          .collection('referrals')
          .where('referrerId', isEqualTo: uid)
          .get();
      for (final d in refs.docs) batch.delete(d.reference);

      await batch.commit();

      // 5. Supprimer le compte Firebase Auth (doit être la dernière étape)
      await _auth.currentUser?.delete();
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    return safeFirebase(() async {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> createUserProfile(UserModel user) async {
    await safeFirebase(() =>
      _db.collection('users').doc(user.uid).set(user.toFirestore()),
    );
  }

  Future<void> updateFCMToken(String uid) async {
    await safeFirebase(() async {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({'fcmToken': token});
      }
    });
  }
}

// ════════════════════════════════════════════════════════════════
// REQUEST SERVICE
// ════════════════════════════════════════════════════════════════
 Stream<int> watchAvailableProviders(String wilaya) {
  return FirebaseFirestore.instance
      .collection('providers')
      .where('isAvailable', isEqualTo: true)
      .where('wilaya', isEqualTo: wilaya)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

Stream<int> watchAvailableProvidersGlobal() {
  return FirebaseFirestore.instance
      .collection('providers')
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
}

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

  Stream<List<ServiceRequest>> getCustomerRequests(String customerId) {
    return _db
      .collection('requests')
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  Stream<List<ServiceRequest>> getActiveCustomerRequests(String customerId) {
    return _db
      .collection('requests')
      .where('customerId', isEqualTo: customerId)
      .where('status', whereIn: ['pending', 'accepted', 'inProgress'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  Stream<ServiceRequest?> getRequest(String requestId) {
    return _db.collection('requests').doc(requestId).snapshots().map(
      (doc) => doc.exists ? ServiceRequest.fromFirestore(doc) : null,
    );
  }

  Stream<List<ServiceRequest>> getProviderRequests(String providerId) {
    return _db
      .collection('requests')
      .where('providerId', isEqualTo: providerId)
      .where('status', whereIn: ['pending', 'accepted', 'inProgress'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

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
    await safeFirebase(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.rejected.name,
      'needsManualAssignment': true,
    }));
  }

  Future<void> startJob(String requestId) async {
    await safeFirebase(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.inProgress.name,
      'startedAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> completeJob(String requestId, int finalPrice) async {
    await safeFirebase(() async {
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
    await safeFirebase(() => _db.collection('requests').doc(requestId).update({
      'status': RequestStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    }));
  }

  // FIX: Atomic rating via batch — pas de race condition
  Future<void> submitReview({
    required String requestId,
    required String customerId,
    required String customerName,
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    await safeFirebase(() async {
      final batch = _db.batch();
      final reviewRef = _db.collection('reviews').doc();
      final review = ReviewModel(
        id: reviewRef.id,
        requestId: requestId,
        customerId: customerId,
        customerName: customerName,
        providerId: providerId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
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
}

// ════════════════════════════════════════════════════════════════
// PROVIDER SERVICE
// ════════════════════════════════════════════════════════════════
class ProviderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createProvider(ProviderModel provider) async {
    await safeFirebase(() async {
      await _db.collection('providers').doc(provider.uid).set(provider.toFirestore());
      await _db.collection('users').doc(provider.uid).update({'role': 'provider'});
    });
  }

  Future<ProviderModel?> getProvider(String uid) async {
    return safeFirebase(() async {
      final doc = await _db.collection('providers').doc(uid).get();
      if (!doc.exists) return null;
      return ProviderModel.fromFirestore(doc);
    });
  }

  Stream<ProviderModel?> watchProvider(String uid) {
    return _db.collection('providers').doc(uid).snapshots().map(
      (doc) => doc.exists ? ProviderModel.fromFirestore(doc) : null,
    );
  }

  Future<void> toggleOnline(String uid, bool isOnline) async {
    await safeFirebase(() => _db.collection('providers').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> updateLocation(String uid, double lat, double lng) async {
    await safeFirebase(() => _db.collection('providers').doc(uid).update({
      'lastLocation': GeoPoint(lat, lng),
      'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
    }));
  }

  // FIX #7: Le paramètre skills est maintenant utilisé pour filtrer par catégorie
  // P1 FIX: filtre par wilaya pour ne montrer que les missions locales.
  // Un prestataire à Oran ne voit plus les demandes d'Alger.
  Stream<List<ServiceRequest>> getNewRequests({
    required String providerId,
    required List<String> skills,
    required String wilaya,
  }) {
    // Chunk skills par 10 (limite Firestore whereIn = 30, mais on garde une marge)
    final chunks = <List<String>>[];
    final filtered = skills.isNotEmpty ? skills : ['__none__'];
    for (var i = 0; i < filtered.length; i += 10) {
      chunks.add(filtered.sublist(i, i > filtered.length - 10 ? filtered.length : i + 10));
    }

    // Merge les streams de chaque chunk (P2 fix inclus)
    final streams = chunks.map((chunk) => _db
      .collection('requests')
      .where('wilaya', isEqualTo: wilaya)          // P1: filtre géographique
      .where('category', whereIn: chunk)
      .where('status', isEqualTo: 'pending')
      .where('needsManualAssignment', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList())
    ).toList();

    if (streams.length == 1) return streams.first;

    // Merge multi-chunk: combine et déduplique par id
    return streams.reduce((a, b) => a.asyncExpand((listA) =>
      b.map((listB) {
        final seen = <String>{};
        return [...listA, ...listB]
          .where((r) => seen.add(r.id))
          .toList()
          ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
      })
    ));
  }

  Stream<List<ReviewModel>> getProviderReviews(String providerId) {
    return _db
      .collection('reviews')
      .where('providerId', isEqualTo: providerId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(ReviewModel.fromFirestore).toList());
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN SERVICE
// ════════════════════════════════════════════════════════════════
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ServiceRequest>> getPendingRequests() {
    return _db
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  Stream<List<ServiceRequest>> getAllRequests() {
    return _db
      .collection('requests')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(ServiceRequest.fromFirestore).toList());
  }

  Stream<List<ProviderModel>> getAllProviders() {
    return _db
      .collection('providers')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ProviderModel.fromFirestore).toList());
  }

  Stream<List<ProviderModel>> getPendingProviders() {
    return _db
      .collection('providers')
      .where('isApproved', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(ProviderModel.fromFirestore).toList());
  }

  Stream<List<UserModel>> getAllCustomers() {
    return _db
      .collection('users')
      .where('role', isEqualTo: 'customer')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromFirestore).toList());
  }

  Future<void> approveProvider(String providerId) async {
    await safeFirebase(() => _db.collection('providers').doc(providerId).update({
      'isApproved': true,
      'isVerified': true,
      'approvedAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> blockProvider(String providerId) async {
    await safeFirebase(() async {
      await _db.collection('providers').doc(providerId).update({'isApproved': false});
      await _db.collection('users').doc(providerId).update({'isBlocked': true});
    });
  }

  Future<void> assignProvider(String requestId, ProviderModel provider) async {
    await safeFirebase(() => _db.collection('requests').doc(requestId).update({
      'providerId': provider.uid,
      'providerName': provider.name,
      'status': RequestStatus.accepted.name,
      'acceptedAt': FieldValue.serverTimestamp(),
      'needsManualAssignment': false,
    }));
  }

  Future<Map<String, int>> getDashboardStats() async {
    try {
      final results = await Future.wait([
        _db.collection('requests').where('status', isEqualTo: 'pending').count().get(),
        _db.collection('requests').where('status', isEqualTo: 'completed').count().get(),
        _db.collection('providers').where('isApproved', isEqualTo: true).count().get(),
        _db.collection('users').where('role', isEqualTo: 'customer').count().get(),
        _db.collection('requests')
          .where('status', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 30))))
          .count().get(),
      ]);
      return {
        'pendingRequests':   results[0].count ?? 0,
        'completedRequests': results[1].count ?? 0,
        'activeProviders':   results[2].count ?? 0,
        'totalCustomers':    results[3].count ?? 0,
        'urgentPending':     results[4].count ?? 0,
      };
    } catch (_) {
      return {'pendingRequests': 0, 'completedRequests': 0,
              'activeProviders': 0, 'totalCustomers': 0, 'urgentPending': 0};
    }
  }

  Future<void> blockUser(String uid) async {
    await safeFirebase(() => _db.collection('users').doc(uid).update({'isBlocked': true}));
  }
}

// ════════════════════════════════════════════════════════════════
// SUBSCRIPTION SERVICE
// ════════════════════════════════════════════════════════════════
class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<SubscriptionModel?> watchSubscription(String customerId) {
    return _db
      .collection('subscriptions')
      .where('customerId', isEqualTo: customerId)
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : SubscriptionModel.fromFirestore(s.docs.first));
  }

  // FIX #4: Utilise ref.id avant .set() — l'ID Firestore est connu dès la création
  Future<void> createSubscription({
    required String customerId,
    required String customerName,
    required SubscriptionPlan plan,
  }) async {
    await safeFirebase(() async {
      final planData = SubscriptionModel.plans[plan]!;
      // Crée la référence d'abord pour obtenir l'ID réel
      final ref = _db.collection('subscriptions').doc();
      final sub = SubscriptionModel(
        id: ref.id, // ← ID Firestore réel, pas une string vide
        customerId: customerId,
        customerName: customerName,
        plan: plan,
        status: SubscriptionStatus.active,
        startDate: DateTime.now(),
        nextBillingDate: DateTime.now().add(const Duration(days: 30)),
        monthlyPrice: planData['price'] as int,
        isPriorityAccess: planData['priority'] as bool,
      );
      await ref.set(sub.toFirestore()); // .set() sur la ref, pas .add()
    });
  }

  // Fonctionne maintenant car subscription.id est l'ID Firestore réel
  Future<void> cancelSubscription(String subscriptionId) async {
    // FIX: guard contre ID vide — évite d'écraser un document aléatoire
    if (subscriptionId.isEmpty) return;
    await safeFirebase(() => _db.collection('subscriptions').doc(subscriptionId).update({
      'status': SubscriptionStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    }));
  }
}

// ════════════════════════════════════════════════════════════════
// CHAT SERVICE  [3 — Chat avec photos]
// ════════════════════════════════════════════════════════════════
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  String _chatPath(String requestId) => 'chats/$requestId/messages';

  Stream<List<ChatMessage>> watchMessages(String requestId) {
    return _db
      .collection(_chatPath(requestId))
      .orderBy('createdAt', descending: false)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
  }

  // Amélioration 2: indicateur de frappe — stocké dans chats/{id}/meta
  Future<void> setTyping(String requestId, String userId, bool isTyping) async {
    await safeFirebase(() => _db
      .collection('chats').doc(requestId)
      .set({'typing_$userId': isTyping}, SetOptions(merge: true)));
  }

  Stream<bool> watchOtherTyping(String requestId, String myId) {
    return _db.collection('chats').doc(requestId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() ?? {};
      return data.entries.any((e) =>
        e.key.startsWith('typing_') &&
        !e.key.endsWith(myId) &&
        e.value == true);
    });
  }

  Future<void> sendText({
    required String requestId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    await safeFirebase(() {
      final msg = ChatMessage(
        id: '',
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        type: MessageType.text,
        text: text.trim(),
        createdAt: DateTime.now(),
      );
      return _db.collection(_chatPath(requestId)).add(msg.toFirestore());
    });
  }

  Future<void> sendImage({
    required String requestId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required File imageFile,
  }) async {
    await safeFirebase(() async {
      // Upload image
      final ref = _storage.ref('chats/$requestId/${_uuid.v4()}.jpg');
      await ref.putFile(imageFile,
        SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      final msg = ChatMessage(
        id: '',
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        type: MessageType.image,
        imageUrl: url,
        createdAt: DateTime.now(),
      );
      await _db.collection(_chatPath(requestId)).add(msg.toFirestore());
    });
  }

  Future<void> markAllRead(String requestId, String userId) async {
    await safeFirebase(() async {
      final unread = await _db
        .collection(_chatPath(requestId))
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();
      if (unread.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    });
  }

  Stream<int> unreadCount(String requestId, String userId) {
    return _db
      .collection(_chatPath(requestId))
      .where('isRead', isEqualTo: false)
      .where('senderId', isNotEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.length);
  }
}

// ════════════════════════════════════════════════════════════════
// FCM NOTIFICATION SERVICE  [4 — Push notifications]
// ════════════════════════════════════════════════════════════════
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    // Request permission (iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and store token
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);

    // Refresh token listener
    _fcm.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await safeFirebase(() => _db.collection('users').doc(user.uid)
      .update({'fcmToken': token}));
  }

  // Foreground message handler — call once in main()
  static void setupForegroundHandler(
    void Function(String title, String body, Map<String, dynamic> data) onMessage,
  ) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif != null) {
        onMessage(
          notif.title ?? '',
          notif.body ?? '',
          message.data,
        );
      }
    });
  }

  // Background tap handler
  static void setupBackgroundTapHandler(
    void Function(Map<String, dynamic> data) onTap,
  ) {
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => onTap(msg.data));
  }
}

// ════════════════════════════════════════════════════════════════
// PROMO CODE SERVICE  [4 — Codes promo admin]
// ════════════════════════════════════════════════════════════════
class PromoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Validate a code and return it if valid, null otherwise
  Future<PromoCode?> validateCode(String code) async {
    return (await safeFirebase(() async {
      final snap = await _db
        .collection('promo_codes')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
      if (snap.docs.isEmpty) return null;
      final promo = PromoCode.fromFirestore(snap.docs.first);
      return promo.isValid ? promo : null;
    }).valueOrNull;
  }

  /// Atomically apply a code (increment usageCount)
  Future<bool> applyCode(String promoId, String userId) async {
    try {
      await _db.runTransaction((t) async {
        final ref = _db.collection('promo_codes').doc(promoId);
        final doc = await t.get(ref);
        final promo = PromoCode.fromFirestore(doc);
        if (!promo.isValid) throw Exception('Code expiré ou épuisé');
        t.update(ref, {'usageCount': FieldValue.increment(1)});
        // Log usage
        t.set(_db.collection('promo_usages').doc(), {
          'promoId': promoId,
          'code': promo.code,
          'userId': userId,
          'usedAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Admin: create promo
  Future<void> createPromo({
    required String code,
    required String description,
    required int discountPercent,
    int? discountFixed,
    required int usageLimit,
    required DateTime expiresAt,
    required String adminId,
  }) async {
    await safeFirebase(() async {
      final ref = _db.collection('promo_codes').doc();
      final promo = PromoCode(
        id: ref.id,
        code: code.toUpperCase(),
        description: description,
        discountPercent: discountPercent,
        discountFixed: discountFixed,
        usageLimit: usageLimit,
        usageCount: 0,
        isActive: true,
        expiresAt: expiresAt,
        createdAt: DateTime.now(),
        createdByAdmin: adminId,
      );
      await ref.set(promo.toFirestore());
    });
  }

  Stream<List<PromoCode>> watchAllPromos() {
    return _db
      .collection('promo_codes')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PromoCode.fromFirestore).toList());
  }

  Future<void> togglePromo(String id, bool active) async {
    await safeFirebase(() =>
      _db.collection('promo_codes').doc(id).update({'isActive': active}));
  }
}

// ════════════════════════════════════════════════════════════════
// RECEIPT PDF SERVICE  [7 — Reçu PDF]
// ════════════════════════════════════════════════════════════════
class ReceiptService {
  /// Generate PDF bytes for a completed request
  static Future<Uint8List> generatePDF(ServiceRequest request) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CHOFLY',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        )),
                      pw.Text('Services à domicile',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('REÇU DE SERVICE',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('N° ${request.id.substring(0, 8).toUpperCase()}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.green700, thickness: 2),
              pw.SizedBox(height: 20),

              // Client / Date
              _pdfRow('Client', request.customerName),
              _pdfRow('Téléphone', request.customerPhone),
              _pdfRow('Date', _formatDate(request.completedAt ?? request.createdAt)),
              _pdfRow('Wilaya', '${request.commune}, ${request.wilaya}'),
              _pdfRow('Adresse', request.address),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Service details
              pw.Text('DÉTAILS DE L\'INTERVENTION',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 10),
              _pdfRow('Catégorie', request.categoryLabel),
              _pdfRow('Problème', request.issueType),
              _pdfRow('Description', request.description),
              if (request.providerName != null)
                _pdfRow('Technicien', request.providerName!),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Price
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL À PAYER (en espèces)',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(
                    '${request.finalPrice ?? request.priceRangeMin} DA',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Merci de votre confiance ! — CHOFLY garantit des artisans vérifiés '
                  'et une intervention en moins de 2h.\nchofly.dz | contact@chofly.dz',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label,
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
          ),
          pw.Expanded(
            child: pw.Text(value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Save PDF to temp dir and return path
  static Future<String> savePDF(Uint8List bytes, String requestId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/recu_chofly_${requestId.substring(0, 8)}.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}

// ════════════════════════════════════════════════════════════════
// REFERRAL SERVICE  [10 — Parrainage]
// ════════════════════════════════════════════════════════════════
class ReferralService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int rewardDA = 500; // DA crédité au parrain

  /// Get or create the referral code for a user (format: CHO-XXXXXX)
  Future<String> getReferralCode(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final existing = doc.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a unique code
    final code = 'CHO-${uid.substring(0, 6).toUpperCase()}';
    await _db.collection('users').doc(uid).update({'referralCode': code});
    return code;
  }

  /// Apply referral code when a new user registers
  Future<void> applyReferral({
    required String refereeId,
    required String refereeName,
    required String refereePhone,
    required String referralCode,
  }) async {
    return safeFirebase(() async {
      // Find referrer
      final snap = await _db
        .collection('users')
        .where('referralCode', isEqualTo: referralCode.toUpperCase())
        .limit(1)
        .get();
      if (snap.docs.isEmpty) return;
      if (snap.docs.first.id == refereeId) return; // can't refer yourself

      final referrer = UserModel.fromFirestore(snap.docs.first);
      final ref = _db.collection('referrals').doc();
      final referral = ReferralModel(
        id: ref.id,
        referrerId: referrer.uid,
        referrerName: referrer.name,
        refereeId: refereeId,
        refereeName: refereeName,
        refereePhone: refereePhone,
        rewardDA: rewardDA,
        createdAt: DateTime.now(),
      );
      await ref.set(referral.toFirestore());
    });
  }

  /// Complete referral when referee places first order — awards credit to referrer
  Future<void> completeReferral(String refereeId) async {
    return safeFirebase(() async {
      final snap = await _db
        .collection('referrals')
        .where('refereeId', isEqualTo: refereeId)
        .where('isCompleted', isEqualTo: false)
        .limit(1)
        .get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      final referralRef = snap.docs.first.reference;
      final referral = ReferralModel.fromFirestore(snap.docs.first);

      // Mark completed
      batch.update(referralRef, {
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Credit referrer's wallet
      batch.set(
        _db.collection('wallets').doc(referral.referrerId),
        {
          'balance': FieldValue.increment(referral.rewardDA),
          'uid': referral.referrerId,
        },
        SetOptions(merge: true),
      );

      // Log credit transaction
      batch.set(_db.collection('wallet_transactions').doc(), {
        'uid': referral.referrerId,
        'amount': referral.rewardDA,
        'type': 'referral_reward',
        'referralId': referral.id,
        'description': 'Parrainage de ${referral.refereeName}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    });
  }

  Stream<List<ReferralModel>> watchReferrals(String uid) {
    return _db
      .collection('referrals')
      .where('referrerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ReferralModel.fromFirestore).toList());
  }

  Future<int> getWalletBalance(String uid) async {
    final doc = await _db.collection('wallets').doc(uid).get();
    if (!doc.exists) return 0;
    return (doc.data()?['balance'] ?? 0) as int;
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS SERVICE  [12 — Firebase Analytics]
// ════════════════════════════════════════════════════════════════
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logRequestCreated(ServiceRequest req) async {
    await _analytics.logEvent(
      name: AnalyticsEvents.requestCreated,
      parameters: {
        'category': req.category.name,
        'wilaya': req.wilaya,
        'issue_type': req.issueType,
        'price_min': req.priceRangeMin,
      },
    );
  }

  Future<void> logRequestCompleted(ServiceRequest req) async {
    await _analytics.logEvent(
      name: AnalyticsEvents.requestCompleted,
      parameters: {
        'category': req.category.name,
        'wilaya': req.wilaya,
        'final_price': req.finalPrice ?? 0,
      },
    );
  }

  Future<void> logPromoApplied(String code, int discount) async {
    await _analytics.logEvent(
      name: AnalyticsEvents.promoApplied,
      parameters: {'code': code, 'discount_da': discount},
    );
  }

  Future<void> logSubscribed(String plan) async {
    await _analytics.logEvent(
      name: AnalyticsEvents.subscribed,
      parameters: {'plan': plan},
    );
  }

  Future<void> logReferralSent() async {
    await _analytics.logEvent(name: AnalyticsEvents.referralSent);
  }

  Future<void> logChatOpened(String requestId) async {
    await _analytics.logEvent(
      name: AnalyticsEvents.chatOpened,
      parameters: {'request_id': requestId},
    );
  }

  Future<void> logReceiptDownloaded() async {
    await _analytics.logEvent(name: AnalyticsEvents.receiptDownloaded);
  }

  Future<void> setUserProperties({required String role, required String wilaya}) async {
    await _analytics.setUserProperty(name: 'role', value: role);
    await _analytics.setUserProperty(name: 'wilaya', value: wilaya);
  }
}

// ════════════════════════════════════════════════════════════════
// STORAGE SERVICE (TÂCHE 5 — upload CIN)
// ════════════════════════════════════════════════════════════════
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<Result<String>> uploadCIN(String uid, File file, String side) async {
    return safeFirebase(() async {
      final ref = _storage.ref('providers/$uid/cin_$side.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    });
  }

  static Future<Result<String>> uploadProfileImage(String uid, File file) async {
    return safeFirebase(() async {
      final ref = _storage.ref('providers/$uid/profile.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    });
  }
}
