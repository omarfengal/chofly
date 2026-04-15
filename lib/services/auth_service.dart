// lib/services/auth_service.dart
// TÂCHE 6 — Refactor: extrait de firebase_service.dart
// Responsabilité unique: authentification Firebase

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/models.dart';
import '../utils/result.dart';
import 'firebase_service.dart' show safeFirebase, safeFirebaseVoid;

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
        verificationCompleted: (c) async => await _auth.signInWithCredential(c),
        verificationFailed: (e) => onError(e.message ?? 'Vérification échouée'),
        codeSent: (id, _) { _verificationId = id; onCodeSent(id); },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) { onError(e.toString()); }
  }

  Future<UserCredential?> verifyOTP(String smsCode) async {
    if (_verificationId == null) return null;
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!, smsCode: smsCode);
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel?> getUserProfile(String uid) async {
    final result = await safeFirebase(() async {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.exists ? UserModel.fromFirestore(doc) : null;
    });
    return result.isSuccess ? result.data : null;
  }

  Future<void> createUserProfile(UserModel user) async {
    await safeFirebaseVoid(() =>
      _db.collection('users').doc(user.uid).set(user.toFirestore()));
  }

  Future<void> updateFCMToken(String uid) async {
    await safeFirebaseVoid(() async {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({'fcmToken': token});
      }
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await safeFirebaseVoid(() =>
      _db.collection('users').doc(uid).update(data));
  }
}
