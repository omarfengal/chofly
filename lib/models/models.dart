import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════════
// USER MODEL
// ════════════════════════════════════════════════════════════════
class UserModel {
  final String uid;
  final String phone;
  final String name;
  final String? fcmToken;
  final String role;
  final String? wilaya;
  final String? commune;
  final String? profileImageUrl;
  final double rating;
  final int totalOrders;
  final bool isActive;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? referralCode;     // code unique format CHO-XXXXXX
  final int walletBalance;        // DA crédités (parrainage)

  const UserModel({
    required this.uid,
    required this.phone,
    required this.name,
    this.fcmToken,
    required this.role,
    this.wilaya,
    this.commune,
    this.profileImageUrl,
    this.rating = 0,
    this.totalOrders = 0,
    this.isActive = true,
    this.isBlocked = false,
    required this.createdAt,
    this.updatedAt,
    this.referralCode,
    this.walletBalance = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phone: d['phone'] ?? '',
      name: d['name'] ?? '',
      fcmToken: d['fcmToken'],
      role: d['role'] ?? 'customer',
      wilaya: d['wilaya'],
      commune: d['commune'],
      profileImageUrl: d['profileImageUrl'],
      rating: (d['rating'] ?? 0).toDouble(),
      totalOrders: d['totalOrders'] ?? 0,
      isActive: d['isActive'] ?? true,
      isBlocked: d['isBlocked'] ?? false,
      referralCode: d['referralCode'] as String?,
      walletBalance: d['walletBalance'] ?? 0,
      // FIX: null-safe createdAt — evite crash si doc créé manuellement
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'phone': phone,
    'name': name,
    'fcmToken': fcmToken,
    'role': role,
    'wilaya': wilaya,
    'commune': commune,
    'profileImageUrl': profileImageUrl,
    'rating': rating,
    'totalOrders': totalOrders,
    'isActive': isActive,
    'isBlocked': isBlocked,
    'referralCode': referralCode,
    'walletBalance': walletBalance,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  UserModel copyWith({
    String? name, String? fcmToken, String? wilaya,
    String? commune, String? profileImageUrl, double? rating,
    int? totalOrders, bool? isActive, bool? isBlocked,
    String? referralCode, int? walletBalance,
  }) => UserModel(
    uid: uid, phone: phone,
    name: name ?? this.name,
    fcmToken: fcmToken ?? this.fcmToken,
    role: role,
    wilaya: wilaya ?? this.wilaya,
    commune: commune ?? this.commune,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    rating: rating ?? this.rating,
    totalOrders: totalOrders ?? this.totalOrders,
    isActive: isActive ?? this.isActive,
    isBlocked: isBlocked ?? this.isBlocked,
    referralCode: referralCode ?? this.referralCode,
    walletBalance: walletBalance ?? this.walletBalance,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ════════════════════════════════════════════════════════════════
// PROVIDER MODEL
// ════════════════════════════════════════════════════════════════

// TÂCHE 5: statut de vérification CIN
enum VerificationStatus { unverified, pending, verified, rejected }

class ProviderModel {
  final String uid;
  final String name;
  final String phone;
  final String? profileImageUrl;
  final List<String> skills;
  final String wilaya;
  final String commune;
  final bool isOnline;
  final bool isApproved;
  final bool isVerified;
  final double rating;
  final int ratingTotal;
  final int ratingCount;
  final int completedJobs;
  final int totalEarnings;
  final String? bio;
  final String? idCardUrl;       // backward compat
  final String? idCardFrontUrl;  // TÂCHE 5: recto CIN
  final String? idCardBackUrl;   // TÂCHE 5: verso CIN
  final VerificationStatus verificationStatus; // TÂCHE 5
  final DateTime createdAt;
  final GeoPoint? lastLocation;

  double get averageRating =>
      ratingCount > 0 ? (ratingTotal / ratingCount) : rating;

  const ProviderModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.profileImageUrl,
    required this.skills,
    required this.wilaya,
    required this.commune,
    this.isOnline = false,
    this.isApproved = false,
    this.isVerified = false,
    this.rating = 0,
    this.ratingTotal = 0,
    this.ratingCount = 0,
    this.completedJobs = 0,
    this.totalEarnings = 0,
    this.bio,
    this.idCardUrl,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    this.verificationStatus = VerificationStatus.unverified,
    required this.createdAt,
    this.lastLocation,
  });

  factory ProviderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProviderModel(
      uid: doc.id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      profileImageUrl: d['profileImageUrl'],
      skills: List<String>.from(d['skills'] ?? []),
      wilaya: d['wilaya'] ?? '',
      commune: d['commune'] ?? '',
      isOnline: d['isOnline'] ?? false,
      isApproved: d['isApproved'] ?? false,
      isVerified: d['isVerified'] ?? false,
      rating: (d['rating'] ?? 0).toDouble(),
      ratingTotal: d['ratingTotal'] ?? 0,
      ratingCount: d['ratingCount'] ?? 0,
      completedJobs: d['completedJobs'] ?? 0,
      totalEarnings: d['totalEarnings'] ?? 0,
      bio: d['bio'],
      idCardUrl: d['idCardUrl'],
      // FIX: null-safe createdAt
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLocation: d['lastLocation'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'phone': phone,
    'profileImageUrl': profileImageUrl,
    'skills': skills,
    'wilaya': wilaya,
    'commune': commune,
    'isOnline': isOnline,
    'isApproved': isApproved,
    'isVerified': isVerified,
    'rating': averageRating,
    'ratingTotal': ratingTotal,
    'ratingCount': ratingCount,
    'completedJobs': completedJobs,
    'totalEarnings': totalEarnings,
    'bio': bio,
    'idCardUrl': idCardUrl,
    'idCardFrontUrl': idCardFrontUrl,
    'idCardBackUrl': idCardBackUrl,
    'verificationStatus': verificationStatus.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastLocation': lastLocation,
  };

  ProviderModel copyWith({
    bool? isOnline, bool? isApproved, bool? isVerified,
    double? rating, int? ratingTotal, int? ratingCount,
    int? completedJobs, int? totalEarnings,
    String? profileImageUrl, GeoPoint? lastLocation,
  }) => ProviderModel(
    uid: uid, name: name, phone: phone,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    skills: skills, wilaya: wilaya, commune: commune,
    isOnline: isOnline ?? this.isOnline,
    isApproved: isApproved ?? this.isApproved,
    isVerified: isVerified ?? this.isVerified,
    rating: rating ?? this.rating,
    ratingTotal: ratingTotal ?? this.ratingTotal,
    ratingCount: ratingCount ?? this.ratingCount,
    completedJobs: completedJobs ?? this.completedJobs,
    totalEarnings: totalEarnings ?? this.totalEarnings,
    bio: bio, idCardUrl: idCardUrl, createdAt: createdAt,
    lastLocation: lastLocation ?? this.lastLocation,
  );
}

// ════════════════════════════════════════════════════════════════
// SERVICE REQUEST MODEL
// ════════════════════════════════════════════════════════════════
enum RequestStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
  rejected,
}

enum ServiceCategory {
  plumbing,
  electricity,
  ac,
  appliances,
}

class ServiceRequest {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? providerId;
  final String? providerName;
  final ServiceCategory category;
  final String issueType;
  final String description;
  final List<String> photoUrls;
  final String wilaya;
  final String commune;
  final String address;
  final GeoPoint? location;
  final RequestStatus status;
  final int priceRangeMin;
  final int priceRangeMax;
  final int? finalPrice;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final bool isRated;
  final String? adminNote;
  final bool needsManualAssignment;

  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.providerId,
    this.providerName,
    required this.category,
    required this.issueType,
    required this.description,
    this.photoUrls = const [],
    required this.wilaya,
    required this.commune,
    required this.address,
    this.location,
    this.status = RequestStatus.pending,
    required this.priceRangeMin,
    required this.priceRangeMax,
    this.finalPrice,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.isRated = false,
    this.adminNote,
    this.needsManualAssignment = true,
  });

  factory ServiceRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ServiceRequest(
      id: doc.id,
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      providerId: d['providerId'],
      providerName: d['providerName'],
      category: ServiceCategory.values.firstWhere(
        (e) => e.name == d['category'],
        orElse: () => ServiceCategory.plumbing,
      ),
      issueType: d['issueType'] ?? '',
      description: d['description'] ?? '',
      photoUrls: List<String>.from(d['photoUrls'] ?? []),
      wilaya: d['wilaya'] ?? '',
      commune: d['commune'] ?? '',
      address: d['address'] ?? '',
      location: d['location'] as GeoPoint?,
      status: RequestStatus.values.firstWhere(
        (e) => e.name == d['status'],
        orElse: () => RequestStatus.pending,
      ),
      priceRangeMin: (d['priceRangeMin'] ?? 0) is int
          ? d['priceRangeMin'] as int
          : int.tryParse(d['priceRangeMin'].toString()) ?? 0,
      priceRangeMax: (d['priceRangeMax'] ?? 0) is int
          ? d['priceRangeMax'] as int
          : int.tryParse(d['priceRangeMax'].toString()) ?? 0,
      finalPrice: d['finalPrice'],
      // FIX: null-safe createdAt
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      acceptedAt: d['acceptedAt'] != null
          ? (d['acceptedAt'] as Timestamp).toDate()
          : null,
      completedAt: d['completedAt'] != null
          ? (d['completedAt'] as Timestamp).toDate()
          : null,
      isRated: d['isRated'] ?? false,
      adminNote: d['adminNote'],
      needsManualAssignment: d['needsManualAssignment'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'providerId': providerId,
    'providerName': providerName,
    'category': category.name,
    'issueType': issueType,
    'description': description,
    'photoUrls': photoUrls,
    'wilaya': wilaya,
    'commune': commune,
    'address': address,
    'location': location,
    'status': status.name,
    'priceRangeMin': priceRangeMin,
    'priceRangeMax': priceRangeMax,
    'finalPrice': finalPrice,
    'createdAt': Timestamp.fromDate(createdAt),
    'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'isRated': isRated,
    'adminNote': adminNote,
    'needsManualAssignment': needsManualAssignment,
  };

  ServiceRequest copyWith({
    String? providerId, String? providerName,
    RequestStatus? status, int? finalPrice,
    DateTime? acceptedAt, DateTime? completedAt,
    bool? isRated, String? adminNote,
  }) => ServiceRequest(
    id: id, customerId: customerId, customerName: customerName,
    customerPhone: customerPhone,
    providerId: providerId ?? this.providerId,
    providerName: providerName ?? this.providerName,
    category: category, issueType: issueType, description: description,
    photoUrls: photoUrls, wilaya: wilaya, commune: commune,
    address: address, location: location,
    status: status ?? this.status,
    priceRangeMin: priceRangeMin, priceRangeMax: priceRangeMax,
    finalPrice: finalPrice ?? this.finalPrice,
    createdAt: createdAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    completedAt: completedAt ?? this.completedAt,
    isRated: isRated ?? this.isRated,
    adminNote: adminNote ?? this.adminNote,
    needsManualAssignment: needsManualAssignment,
  );

  String get categoryLabel {
    switch (category) {
      case ServiceCategory.plumbing:    return 'Plomberie';
      case ServiceCategory.electricity: return 'Électricité';
      case ServiceCategory.ac:          return 'Climatisation';
      case ServiceCategory.appliances:  return 'Électroménager';
    }
  }

  String get statusLabel {
    switch (status) {
      case RequestStatus.pending:    return 'En attente';
      case RequestStatus.accepted:   return 'Accepté';
      case RequestStatus.inProgress: return 'En cours';
      case RequestStatus.completed:  return 'Terminé';
      case RequestStatus.cancelled:  return 'Annulé';
      case RequestStatus.rejected:   return 'Refusé';
    }
  }
}

// ════════════════════════════════════════════════════════════════
// REVIEW MODEL
// ════════════════════════════════════════════════════════════════
class ReviewModel {
  final String id;
  final String requestId;
  final String customerId;
  final String customerName;
  final String providerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.customerName,
    required this.providerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      requestId: d['requestId'] ?? '',
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      providerId: d['providerId'] ?? '',
      rating: d['rating'] ?? 5,
      comment: d['comment'],
      // FIX: null-safe createdAt
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'requestId': requestId,
    'customerId': customerId,
    'customerName': customerName,
    'providerId': providerId,
    'rating': rating,
    'comment': comment,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ════════════════════════════════════════════════════════════════
// STATIC DATA — Categories & Issues
// ════════════════════════════════════════════════════════════════
class ServiceData {
  static const Map<ServiceCategory, Map<String, dynamic>> categories = {
    ServiceCategory.plumbing: {
      'label': 'Plomberie',
      'labelAr': 'سباكة',
      'icon': '🔧',
      'issues': [
        'Fuite d\'eau',
        'Tuyau bouché',
        'Robinet cassé',
        'Chauffe-eau',
        'WC bouché',
        'Autre',
      ],
      'priceMin': 1500,
      'priceMax': 5000,
    },
    ServiceCategory.electricity: {
      'label': 'Électricité',
      'labelAr': 'كهرباء',
      'icon': '⚡',
      'issues': [
        'Panne de courant',
        'Prise défectueuse',
        'Disjoncteur',
        'Installation lampe',
        'Court-circuit',
        'Autre',
      ],
      'priceMin': 1000,
      'priceMax': 4000,
    },
    ServiceCategory.ac: {
      'label': 'Climatisation',
      'labelAr': 'تكييف',
      'icon': '❄️',
      'issues': [
        'Clim ne refroidit pas',
        'Clim ne s\'allume pas',
        'Fuite d\'eau',
        'Bruit anormal',
        'Installation',
        'Autre',
      ],
      'priceMin': 2000,
      'priceMax': 8000,
    },
    ServiceCategory.appliances: {
      'label': 'Électroménager',
      'labelAr': 'أجهزة كهرومنزلية',
      'icon': '🏠',
      'issues': [
        'Machine à laver',
        'Réfrigérateur',
        'Cuisinière',
        'Chauffe-eau électrique',
        'Lave-vaisselle',
        'Autre',
      ],
      'priceMin': 1500,
      'priceMax': 6000,
    },
  };

  static const List<String> wilayas = [
    // 01–10
    'Adrar', 'Chlef', 'Laghouat', 'Oum El Bouaghi', 'Batna',
    'Béjaïa', 'Biskra', 'Béchar', 'Blida', 'Bouira',
    // 11–20
    'Tamanrasset', 'Tébessa', 'Tlemcen', 'Tiaret', 'Tizi Ouzou',
    'Alger', 'Djelfa', 'Jijel', 'Sétif', 'Saïda',
    // 21–30
    'Skikda', 'Sidi Bel Abbès', 'Annaba', 'Guelma', 'Constantine',
    'Médéa', 'Mostaganem', 'M\'Sila', 'Mascara', 'Ouargla',
    // 31–40
    'Oran', 'El Bayadh', 'Illizi', 'Bordj Bou Arréridj', 'Boumerdès',
    'El Tarf', 'Tindouf', 'Tissemsilt', 'El Oued', 'Khenchela',
    // 41–50
    'Souk Ahras', 'Tipaza', 'Mila', 'Aïn Defla', 'Naâma',
    'Aïn Témouchent', 'Ghardaïa', 'Relizane', 'Timimoun', 'Bordj Badji Mokhtar',
    // 51–58  (wilayas déléguées créées en 2019)
    'Ouled Djellal', 'Béni Abbès', 'In Salah', 'In Guezzam',
    'Touggourt', 'Djanet', 'El M\'Ghair', 'El Meniaa',
  ];
}

// ════════════════════════════════════════════════════════════════
// PROMO CODE MODEL  [4 — Admin promo codes]
// ════════════════════════════════════════════════════════════════
class PromoCode {
  final String id;
  final String code;
  final String description;
  final int discountPercent;      // 0–100
  final int? discountFixed;       // DA fixed amount, nullable
  final int usageLimit;           // max total uses
  final int usageCount;           // current uses
  final bool isActive;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String createdByAdmin;

  const PromoCode({
    required this.id,
    required this.code,
    required this.description,
    required this.discountPercent,
    this.discountFixed,
    required this.usageLimit,
    required this.usageCount,
    required this.isActive,
    required this.expiresAt,
    required this.createdAt,
    required this.createdByAdmin,
  });

  bool get isValid =>
      isActive && usageCount < usageLimit && expiresAt.isAfter(DateTime.now());

  int discountAmount(int basePrice) {
    if (discountFixed != null) return discountFixed!.clamp(0, basePrice);
    return (basePrice * discountPercent / 100).round();
  }

  factory PromoCode.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PromoCode(
      id: doc.id,
      code: d['code'] ?? '',
      description: d['description'] ?? '',
      discountPercent: d['discountPercent'] ?? 0,
      discountFixed: d['discountFixed'],
      usageLimit: d['usageLimit'] ?? 0,
      usageCount: d['usageCount'] ?? 0,
      isActive: d['isActive'] ?? true,
      expiresAt: d['expiresAt'] != null
          ? (d['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdByAdmin: d['createdByAdmin'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'code': code.toUpperCase(),
    'description': description,
    'discountPercent': discountPercent,
    'discountFixed': discountFixed,
    'usageLimit': usageLimit,
    'usageCount': usageCount,
    'isActive': isActive,
    'expiresAt': Timestamp.fromDate(expiresAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'createdByAdmin': createdByAdmin,
  };
}

// ════════════════════════════════════════════════════════════════
// CHAT MESSAGE MODEL  [3 — Chat avec photos]
// ════════════════════════════════════════════════════════════════
enum MessageType { text, image, system }

class ChatMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'customer' | 'provider'
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.type,
    this.text,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      requestId: d['requestId'] ?? '',
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      senderRole: d['senderRole'] ?? 'customer',
      type: MessageType.values.firstWhere(
        (e) => e.name == d['type'],
        orElse: () => MessageType.text,
      ),
      text: d['text'],
      imageUrl: d['imageUrl'],
      isRead: d['isRead'] ?? false,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'requestId': requestId,
    'senderId': senderId,
    'senderName': senderName,
    'senderRole': senderRole,
    'type': type.name,
    'text': text,
    'imageUrl': imageUrl,
    'isRead': isRead,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

// ════════════════════════════════════════════════════════════════
// REFERRAL MODEL  [10 — Parrainage]
// ════════════════════════════════════════════════════════════════
class ReferralModel {
  final String id;
  final String referrerId;       // qui parraine
  final String referrerName;
  final String refereeId;        // qui est parrainé
  final String refereeName;
  final String refereePhone;
  final bool isCompleted;        // true quand la 1ère commande est faite
  final int rewardDA;            // montant en DA accordé au parrain
  final DateTime createdAt;
  final DateTime? completedAt;

  const ReferralModel({
    required this.id,
    required this.referrerId,
    required this.referrerName,
    required this.refereeId,
    required this.refereeName,
    required this.refereePhone,
    this.isCompleted = false,
    required this.rewardDA,
    required this.createdAt,
    this.completedAt,
  });

  factory ReferralModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReferralModel(
      id: doc.id,
      referrerId: d['referrerId'] ?? '',
      referrerName: d['referrerName'] ?? '',
      refereeId: d['refereeId'] ?? '',
      refereeName: d['refereeName'] ?? '',
      refereePhone: d['refereePhone'] ?? '',
      isCompleted: d['isCompleted'] ?? false,
      rewardDA: d['rewardDA'] ?? 500,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: d['completedAt'] != null
          ? (d['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'referrerId': referrerId,
    'referrerName': referrerName,
    'refereeId': refereeId,
    'refereeName': refereeName,
    'refereePhone': refereePhone,
    'isCompleted': isCompleted,
    'rewardDA': rewardDA,
    'createdAt': Timestamp.fromDate(createdAt),
    'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
  };
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS EVENT NAMES  [12 — Firebase Analytics]
// ════════════════════════════════════════════════════════════════
class AnalyticsEvents {
  static const String requestCreated  = 'request_created';
  static const String requestAccepted = 'request_accepted';
  static const String requestCompleted = 'request_completed';
  static const String requestCancelled = 'request_cancelled';
  static const String promoApplied    = 'promo_applied';
  static const String subscribed      = 'subscription_created';
  static const String referralSent    = 'referral_sent';
  static const String referralCompleted = 'referral_completed';
  static const String chatOpened      = 'chat_opened';
  static const String receiptDownloaded = 'receipt_downloaded';
}
