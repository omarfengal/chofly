import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionPlan { monthly, annual }
enum SubscriptionStatus { active, cancelled, expired }

class SubscriptionModel {
  final String id;
  final String customerId;
  final String customerName;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime nextBillingDate;
  final int monthlyPrice;
  final bool isPriorityAccess;
  final int interventionsUsed;   // [#11] compteur mensuel

  const SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.plan,
    required this.status,
    required this.startDate,
    required this.nextBillingDate,
    required this.monthlyPrice,
    required this.isPriorityAccess,
    this.interventionsUsed = 0,
  });

  static const Map<SubscriptionPlan, Map<String, dynamic>> plans = {
    SubscriptionPlan.monthly: {
      'name': 'Foyer Protégé Mensuel',
      'price': 2990,
      'interventionsPerMonth': 2,
      'discount': 15,
      'priority': true,
      'description': '2 interventions/mois + -15% + Priorité 1h',
    },
    SubscriptionPlan.annual: {
      'name': 'Foyer Protégé Annuel',
      'price': 28790,
      'interventionsPerMonth': 999, // unlimited
      'discount': 20,
      'priority': true,
      'description': 'Illimité + -20% + toutes catégories',
    },
  };

  int get discountPercent => plans[plan]!['discount'] as int;
  int get monthlyInterventions => plans[plan]!['interventionsPerMonth'] as int;
  String get planName => plans[plan]!['name'] as String;
  bool get isActive => status == SubscriptionStatus.active;
  bool get isUnlimited => plan == SubscriptionPlan.annual;

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      id: doc.id,
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.name == d['plan'],
        orElse: () => SubscriptionPlan.monthly,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == d['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      startDate: d['startDate'] != null
          ? (d['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      nextBillingDate: d['nextBillingDate'] != null
          ? (d['nextBillingDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      monthlyPrice: d['monthlyPrice'] ?? 2990,
      isPriorityAccess: d['isPriorityAccess'] ?? true,
      interventionsUsed: d['interventionsUsed'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'customerId': customerId,
    'customerName': customerName,
    'plan': plan.name,
    'status': status.name,
    'startDate': Timestamp.fromDate(startDate),
    'nextBillingDate': Timestamp.fromDate(nextBillingDate),
    'monthlyPrice': monthlyPrice,
    'isPriorityAccess': isPriorityAccess,
    'interventionsUsed': interventionsUsed,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
