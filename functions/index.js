// CHOFLY Cloud Functions v2.0
// Deploy: firebase deploy --only functions

const functions = require("firebase-functions");
const admin     = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

// ════════════════════════════════════════════════════════════════
// HELPER — send FCM to a user  [#4]
// ════════════════════════════════════════════════════════════════
async function notifyUser(uid, title, body, data = {}) {
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return;
    const token = userDoc.data().fcmToken;
    if (!token) return;

    await admin.messaging().send({
      token,
      notification: { title, body },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: { channelId: "chofly_main", sound: "default" },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  } catch (err) {
    functions.logger.error("FCM error for uid", uid, ":", err.message);
  }
}

// ════════════════════════════════════════════════════════════════
// 1. REQUEST STATUS → FCM notification  [#4]
// ════════════════════════════════════════════════════════════════
exports.onRequestStatusChange = functions.firestore
  .document("requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();
    const reqId  = context.params.requestId;

    if (before.status === after.status) return null;

    const customerNotifs = {
      accepted:   { title: "✅ Technicien trouvé !",
                    body: `${after.providerName || "Un technicien"} est en route — arrivée en moins de 2h.` },
      inProgress: { title: "🔧 Intervention en cours",
                    body: "Le technicien est sur place et travaille." },
      completed:  { title: "🎉 Service terminé !",
                    body: "Mission accomplie ! Évaluez votre technicien." },
      cancelled:  { title: "❌ Demande annulée",
                    body: "Votre demande a été annulée." },
      rejected:   { title: "🔄 Nouvelle recherche",
                    body: "Nous cherchons un autre technicien disponible." },
    };

    const notif = customerNotifs[after.status];
    if (notif) {
      await notifyUser(after.customerId, notif.title, notif.body, {
        requestId: reqId,
        type: after.status,
      });
    }

    // Notify provider when assigned
    if (!before.providerId && after.providerId && after.status === "accepted") {
      await notifyUser(
        after.providerId,
        "🔧 Nouvelle mission CHOFLY",
        `${after.category} — ${after.commune}, ${after.wilaya}`,
        { requestId: reqId, type: "new_assignment" }
      );
    }

    return null;
  });

// ════════════════════════════════════════════════════════════════
// 2. PROVIDER APPROVED → FCM  [#4]
// ════════════════════════════════════════════════════════════════
exports.onProviderApproved = functions.firestore
  .document("providers/{providerId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.isApproved === after.isApproved) return null;
    if (!after.isApproved) return null;

    await notifyUser(
      context.params.providerId,
      "🎊 Profil approuvé !",
      "Votre profil CHOFLY est validé. Activez votre disponibilité pour recevoir des missions.",
      { type: "provider_approved" }
    );
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 3. NEW CHAT MESSAGE → FCM  [#3 + #4]
// ════════════════════════════════════════════════════════════════
exports.onNewChatMessage = functions.firestore
  .document("chats/{requestId}/messages/{msgId}")
  .onCreate(async (snap, context) => {
    const msg       = snap.data();
    const requestId = context.params.requestId;

    // Get the request to find the other participant
    const reqDoc = await db.collection("requests").doc(requestId).get();
    if (!reqDoc.exists) return null;
    const req = reqDoc.data();

    // Determine recipient (the one who didn't send)
    const recipientUid = msg.senderId === req.customerId
      ? req.providerId
      : req.customerId;

    if (!recipientUid) return null;

    const preview = msg.type === "image"
      ? "📷 Photo"
      : msg.text?.substring(0, 60) || "…";

    await notifyUser(
      recipientUid,
      `💬 ${msg.senderName}`,
      preview,
      { requestId, type: "chat_message", msgId: context.params.msgId }
    );
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 4. AUTO-TIMEOUT: cancel pending requests after 45 min
// ════════════════════════════════════════════════════════════════
exports.timeoutPendingRequests = functions.pubsub
  .schedule("every 15 minutes")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 45 * 60 * 1000)
    );
    const stale = await db.collection("requests")
      .where("status", "==", "pending")
      .where("createdAt", "<", cutoff)
      .get();

    const batch = db.batch();
    stale.docs.forEach(doc => {
      batch.update(doc.ref, {
        status: "cancelled",
        adminNote: "Annulé automatiquement — aucun technicien disponible",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    // Notify each customer
    for (const doc of stale.docs) {
      const { customerId, id } = doc.data();
      await notifyUser(customerId,
        "⏱️ Demande expirée",
        "Aucun technicien disponible. Réessayez plus tard.",
        { requestId: id || doc.id, type: "timeout" }
      );
    }

    functions.logger.info(`Timeout: ${stale.size} requêtes annulées`);
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 5. RATE LIMIT — max 3 active requests per customer  [#8]
// ════════════════════════════════════════════════════════════════
exports.limitActiveRequests = functions.firestore
  .document("requests/{requestId}")
  .onCreate(async (snap) => {
    const { customerId } = snap.data();
    const counterRef = db.collection("_counters").doc(`active_${customerId}`);

    try {
      await db.runTransaction(async (t) => {
        const counterDoc = await t.get(counterRef);
        const currentCount = counterDoc.exists
          ? (counterDoc.data().count || 0) : 0;

        if (currentCount >= 3) {
          t.update(snap.ref, {
            status: "cancelled",
            adminNote: "Limite de 3 demandes actives atteinte",
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          functions.logger.warn(`Rate limit hit for customer ${customerId}`);
        } else {
          t.set(counterRef, { count: currentCount + 1 }, { merge: true });
        }
      });
    } catch (err) {
      functions.logger.error("limitActiveRequests error:", err);
    }
    return null;
  });

// Decrement counter when request reaches terminal status
exports.decrementActiveCounter = functions.firestore
  .document("requests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    const terminal = ["completed", "cancelled", "rejected"];

    if (!terminal.includes(before.status) && terminal.includes(after.status)) {
      const ref = db.collection("_counters").doc(`active_${after.customerId}`);
      await ref.set(
        { count: admin.firestore.FieldValue.increment(-1) },
        { merge: true }
      );
    }
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 6. RECALC PROVIDER RATING (guard double-invocation)
// ════════════════════════════════════════════════════════════════
exports.recalcProviderRating = functions.firestore
  .document("providers/{providerId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    if (before.ratingTotal === after.ratingTotal &&
        before.ratingCount === after.ratingCount) return null;

    const count  = after.ratingCount || 0;
    const total  = after.ratingTotal || 0;
    if (count === 0) return null;

    const newAvg = Math.round((total / count) * 10) / 10;
    if (before.rating === newAvg) return null;

    await change.after.ref.update({ rating: newAvg });
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 7. UPDATE CUSTOMER TOTAL ORDERS on completion
// ════════════════════════════════════════════════════════════════
exports.updateCustomerStats = functions.firestore
  .document("requests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.status !== "inProgress" || after.status !== "completed") return null;

    const batch = db.batch();

    // Increment customer totalOrders
    batch.update(db.collection("users").doc(after.customerId), {
      totalOrders: admin.firestore.FieldValue.increment(1),
    });

    // [#10] Complete referral if customer's first order
    const userDoc = await db.collection("users").doc(after.customerId).get();
    if (userDoc.exists && (userDoc.data().totalOrders || 0) === 0) {
      // First order → complete any pending referral
      const refSnap = await db.collection("referrals")
        .where("refereeId", "==", after.customerId)
        .where("isCompleted", "==", false)
        .limit(1)
        .get();

      if (!refSnap.empty) {
        const ref     = refSnap.docs[0];
        const referral = ref.data();
        batch.update(ref.ref, {
          isCompleted: true,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Credit referrer wallet
        batch.set(
          db.collection("wallets").doc(referral.referrerId),
          { balance: admin.firestore.FieldValue.increment(referral.rewardDA || 500),
            uid: referral.referrerId },
          { merge: true }
        );
        batch.set(db.collection("wallet_transactions").doc(), {
          uid: referral.referrerId,
          amount: referral.rewardDA || 500,
          type: "referral_reward",
          referralId: ref.id,
          description: `Parrainage de ${referral.refereeName}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Notify referrer
        await notifyUser(
          referral.referrerId,
          "🎁 Crédit parrainage !",
          `${referral.refereeName} a passé sa première commande. +${referral.rewardDA || 500} DA crédités.`,
          { type: "referral_reward" }
        );
      }
    }

    await batch.commit();
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 8. MONTHLY SUBSCRIPTION RESET — reset interventionsUsed  [#11]
// ════════════════════════════════════════════════════════════════
exports.resetSubscriptionUsage = functions.pubsub
  .schedule("0 0 1 * *")    // 1st of each month at midnight
  .timeZone("Africa/Algiers")
  .onRun(async () => {
    const actives = await db.collection("subscriptions")
      .where("status", "==", "active")
      .get();

    const batch = db.batch();
    actives.docs.forEach(doc => {
      batch.update(doc.ref, {
        interventionsUsed: 0,
        nextBillingDate: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        ),
      });
    });
    await batch.commit();
    functions.logger.info(`Reset ${actives.size} subscriptions usage`);
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 9. INCREMENT SUBSCRIPTION USAGE on completion  [#11]
// ════════════════════════════════════════════════════════════════
exports.trackSubscriptionUsage = functions.firestore
  .document("requests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.status !== "inProgress" || after.status !== "completed") return null;

    // Find active subscription for this customer
    const subs = await db.collection("subscriptions")
      .where("customerId", "==", after.customerId)
      .where("status", "==", "active")
      .limit(1)
      .get();

    if (!subs.empty) {
      await subs.docs[0].ref.update({
        interventionsUsed: admin.firestore.FieldValue.increment(1),
      });
    }
    return null;
  });

// ════════════════════════════════════════════════════════════════
// 10. ANALYTICS — log key events to Firestore for admin  [#12]
// ════════════════════════════════════════════════════════════════
exports.logAnalyticsEvent = functions.firestore
  .document("requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.status === after.status) return null;

    // Write to analytics_events collection for admin dashboard
    await db.collection("analytics_events").add({
      event: after.status === "completed" ? "request_completed" : `request_${after.status}`,
      requestId: context.params.requestId,
      category: after.category,
      wilaya: after.wilaya,
      hour: new Date().getHours(),
      dayOfWeek: new Date().getDay(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  });
