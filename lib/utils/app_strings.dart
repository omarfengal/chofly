// lib/utils/app_strings.dart
// Single source of truth for all UI text

class AppStrings {
  // ── Brand ────────────────────────────────────────────────────
  static const appName       = 'CHOFLY';
  static const tagline       = 'Services à domicile — intervention < 2h garantie';
  static const taglineShort  = 'Intervention < 2h';

  // ── Trust elements ───────────────────────────────────────────
  static const trustMissions  = '+500 missions';
  static const trustVerified  = 'Artisans vérifiés';
  static const trustCash      = 'Cash après service';
  static const trustGuarantee = 'Satisfait ou refait 48h';
  static const verifiedBadge  = 'CHOFLY Vérifié';

  // ── Request flow ─────────────────────────────────────────────
  static const newRequest       = 'Nouvelle demande';
  static const requestConfirmed = 'Demande envoyée !';
  static const requestCancelled = 'Demande annulée';
  static const chooseService    = 'Choisissez un service';
  static const chooseProblem    = 'Décrivez le problème';
  static const confirm          = 'Confirmer';
  static const cancel           = 'Annuler';

  // ── Status messages ──────────────────────────────────────────
  static const statusPending    = 'Recherche d\'un technicien...';
  static const statusAccepted   = 'Technicien en route — arrivée < 2h';
  static const statusInProgress = 'Intervention en cours';
  static const statusCompleted  = 'Service terminé avec succès';
  static const statusCancelled  = 'Demande annulée';
  static const statusRejected   = 'Recherche d\'un autre technicien...';

  // ── Errors ───────────────────────────────────────────────────
  static const noInternet       = 'Pas de connexion internet. Vérifiez votre réseau.';
  static const genericError     = 'Une erreur est survenue. Réessayez.';
  static const sessionExpired   = 'Session expirée. Reconnectez-vous.';
  static const phoneInvalid     = 'Numéro invalide (ex: 0661234567)';
  static const noProvider       = 'Aucun technicien disponible pour le moment. Réessayez dans quelques minutes.';

  // ── Payment ──────────────────────────────────────────────────
  static const paymentNote      = 'Paiement en espèces après intervention';
  static const paymentCash      = 'Cash uniquement';

  // ── Provider ─────────────────────────────────────────────────
  static const providerPending  = 'Profil en cours de vérification (24–48h)';
  static const providerApproved = 'Profil validé ! Activez votre disponibilité.';

  // ── Subscription ─────────────────────────────────────────────
  static const subBasicName    = 'Foyer Essentiel';
  static const subPremiumName  = 'Foyer Protégé';
  static const subBasicPrice   = '1 500 DA/mois';
  static const subPremiumPrice = '2 500 DA/mois';
}
