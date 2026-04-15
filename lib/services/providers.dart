import 'dart:async';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/result.dart';

// ════════════════════════════════════════════════════════════════
// AUTH PROVIDER
// ════════════════════════════════════════════════════════════════
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // BUG12 FIX: store subscription so it can be cancelled in dispose()
  StreamSubscription<User?>? _authSubscription;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isCustomer => _userModel?.role == 'customer';
  bool get isProvider => _userModel?.role == 'provider';
  bool get isAdmin => _userModel?.role == 'admin';

  AuthProvider() {
    // BUG12 FIX: assign subscription so dispose() can cancel it
    _authSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  @override
  void dispose() {
    // BUG12 FIX: cancel Firebase Auth listener to prevent memory leak
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      _userModel = await _authService.getUserProfile(user.uid);
      await _authService.updateFCMToken(user.uid);
    } else {
      _userModel = null;
    }
    notifyListeners();
  }

  Future<void> sendOTP(String phone, Function(String) onCodeSent, Function(String) onError) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await _authService.sendOTP(
      phoneNumber: phone,
      onCodeSent: (id) {
        _isLoading = false;
        notifyListeners();
        onCodeSent(id);
      },
      onError: (e) {
        _isLoading = false;
        _error = e;
        notifyListeners();
        onError(e);
      },
    );
  }

  Future<bool> verifyOTP(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final cred = await _authService.verifyOTP(code);
      if (cred?.user != null) {
        _firebaseUser = cred!.user;
        _userModel = await _authService.getUserProfile(cred.user!.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      _error = 'Code OTP incorrect. Réessayez.';
      notifyListeners();
      return false;
    } on Exception catch (e) {
      _isLoading = false;
      // Message utilisateur propre — pas de stack trace brut
      _error = e.toString().contains('invalid-verification-code')
          ? 'Code incorrect. Vérifiez le SMS.'
          : 'Erreur de connexion. Réessayez.';
      notifyListeners();
      return false;
    }
  }

  Future<void> createProfile(UserModel user) async {
    await _authService.createUserProfile(user);
    _userModel = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _firebaseUser = null;
    _userModel = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ════════════════════════════════════════════════════════════════
// REQUEST PROVIDER
// ════════════════════════════════════════════════════════════════
class RequestProvider extends ChangeNotifier {
  final RequestService _requestService = RequestService();

  bool _isLoading = false;
  String? _error;
  String? _activeRequestId;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get activeRequestId => _activeRequestId;

  Future<Result<String>> submitRequest(ServiceRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _requestService.createRequest(request);
    _isLoading = false;
    if (result is Success<String>) {
      _activeRequestId = result.value;
      _error = null;
    } else if (result is Failure<String>) {
      _error = result.userMessage;
    }
    notifyListeners();
    return result;
  }

  Future<void> cancelRequest(String requestId) async {
    await _requestService.cancelRequest(requestId);
  }

  Future<void> submitReview({
    required String requestId,
    required String customerId,
    required String customerName,
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    await _requestService.submitReview(
      requestId: requestId,
      customerId: customerId,
      customerName: customerName,
      providerId: providerId,
      rating: rating,
      comment: comment,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
