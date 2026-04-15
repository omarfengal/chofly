// lib/config/app_config.dart
//
// ══════════════════════════════════════════════════════════════
//  CONFIGURATION CENTRALE CHOFLY
//  → Modifier ici avant chaque mise en production
// ══════════════════════════════════════════════════════════════

class AppConfig {
  AppConfig._();

  // ── Support WhatsApp ────────────────────────────────────────
  // Format international sans '+' ni '00'
  // Ex: 213771234567  (Algérie 07 71 23 45 67)
  static const String supportWhatsAppNumber = '213XXXXXXXXX'; // ← REMPLACER

  // ── URLs légales (hébergées sur ton site ou Firebase Hosting) ─
  static const String cguUrl =
      'https://chofly.app/cgu';           // ← REMPLACER
  static const String privacyUrl =
      'https://chofly.app/confidentialite'; // ← REMPLACER

  // ── App info ────────────────────────────────────────────────
  static const String appName    = 'CHOFLY';
  static const String appVersion = '1.0.0';

  // ── WhatsApp helpers ────────────────────────────────────────
  static String whatsappLink(String message) =>
      'https://wa.me/$supportWhatsAppNumber?text=${Uri.encodeComponent(message)}';

  static String get customerSupportLink => whatsappLink(
    'Bonjour CHOFLY, j\'ai besoin d\'aide',
  );

  static String get providerSupportLink => whatsappLink(
    'Bonjour, je suis un artisan en attente de validation CHOFLY',
  );
}
