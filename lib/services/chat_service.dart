// lib/services/chat_service.dart
// TÂCHE 6 — Refactor extrait de firebase_service.dart
// TÂCHE 4 — Chat amélioré: read receipts visibles, quick replies

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'firebase_service.dart' show safeFirebase, safeFirebaseVoid;

// Quick replies prédéfinis — contexte algérien
const kQuickReplies = [
  'Je suis en route 🚗',
  'J\'arrive dans 10 min',
  'J\'arrive dans 30 min',
  'Pouvez-vous préciser l\'adresse ?',
  'Merci, j\'arrive',
  'Travaux terminés ✅',
  'Paiement reçu, merci !',
];

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  String _chatPath(String requestId) => 'chats/$requestId/messages';

  // ── Watch messages ─────────────────────────────────────────────
  Stream<List<ChatMessage>> watchMessages(String requestId) {
    return _db.collection(_chatPath(requestId))
        .orderBy('createdAt', descending: false)
        .limit(100).snapshots()
        .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());
  }

  // ── Typing indicator ───────────────────────────────────────────
  Future<void> setTyping(String requestId, String userId, bool isTyping) async {
    await safeFirebaseVoid(() => _db
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

  // ── Send text ──────────────────────────────────────────────────
  Future<void> sendText({
    required String requestId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    await safeFirebaseVoid(() {
      final msg = ChatMessage(
        id: '', requestId: requestId,
        senderId: senderId, senderName: senderName,
        senderRole: senderRole, type: MessageType.text,
        text: text.trim(), createdAt: DateTime.now(),
      );
      return _db.collection(_chatPath(requestId)).add(msg.toFirestore());
    });
  }

  // ── Send image ─────────────────────────────────────────────────
  Future<void> sendImage({
    required String requestId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required File imageFile,
  }) async {
    await safeFirebaseVoid(() async {
      final ref = _storage.ref('chats/$requestId/${_uuid.v4()}.jpg');
      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      final msg = ChatMessage(
        id: '', requestId: requestId,
        senderId: senderId, senderName: senderName,
        senderRole: senderRole, type: MessageType.image,
        imageUrl: url, createdAt: DateTime.now(),
      );
      await _db.collection(_chatPath(requestId)).add(msg.toFirestore());
    });
  }

  // ── TÂCHE 4: Read receipts — marquer tous les messages lus ─────
  // Appelé dès que l'écran de chat est ouvert/visible
  Future<void> markAllRead(String requestId, String userId) async {
    await safeFirebaseVoid(() async {
      final unread = await _db
          .collection(_chatPath(requestId))
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();
      if (unread.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(), // NOUVEAU: timestamp lu
        });
      }
      await batch.commit();
    });
  }

  // ── Unread count (pour badge dans AppBar) ──────────────────────
  Stream<int> unreadCount(String requestId, String userId) {
    return _db
        .collection(_chatPath(requestId))
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.length);
  }
}
