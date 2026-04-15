// ════════════════════════════════════════════════════════════════
// RESULT TYPE  — P3
// Remplace le pattern "retourner null en cas d'erreur" de safeFirebase.
// Chaque couche (service → provider → UI) sait pourquoi ça a échoué.
// ════════════════════════════════════════════════════════════════

/// Code d'erreur typé — l'UI peut choisir le message à afficher.
enum AppErrorCode {
  network,       // SocketException — pas de connexion
  notFound,      // Document Firestore absent
  permission,    // Règles de sécurité refusent l'accès
  alreadyTaken,  // Race condition (mission déjà acceptée)
  sessionExpired,// Utilisateur déconnecté
  unknown,       // Erreur non catégorisée
}

/// Résultat scellé : soit un succès avec valeur, soit un échec typé.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
    Success<T> s => s.value,
    Failure<T> _ => null,
  };

  String? get errorMessage => switch (this) {
    Success<T> _ => null,
    Failure<T> f => f.userMessage,
  };

  /// Transforme la valeur si succès, laisse l'erreur intacte.
  Result<R> map<R>(R Function(T) transform) => switch (this) {
    Success<T> s => Success(transform(s.value)),
    Failure<T> f => Failure(f.code, f.userMessage, cause: f.cause),
  };
}

/// Succès avec valeur.
final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// Échec avec code typé + message utilisateur.
final class Failure<T> extends Result<T> {
  final AppErrorCode code;
  final String userMessage;
  final Object? cause;

  const Failure(this.code, this.userMessage, {this.cause});
}

// ── Messages utilisateur par défaut ──────────────────────────
extension AppErrorCodeX on AppErrorCode {
  String get defaultMessage => switch (this) {
    AppErrorCode.network       => 'Pas de connexion internet. Réessayez.',
    AppErrorCode.notFound      => 'Ressource introuvable.',
    AppErrorCode.permission    => 'Accès refusé.',
    AppErrorCode.alreadyTaken  => 'Cette mission a déjà été acceptée.',
    AppErrorCode.sessionExpired=> 'Session expirée. Reconnectez-vous.',
    AppErrorCode.unknown       => 'Une erreur est survenue. Réessayez.',
  };
}
