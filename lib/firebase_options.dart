// lib/firebase_options.dart
//
// ══════════════════════════════════════════════════════════════
//  CONFIGURATION FIREBASE — À COMPLÉTER AVANT LE BUILD
// ══════════════════════════════════════════════════════════════
//
//  ÉTAPES:
//  1. Créer un projet sur console.firebase.google.com
//  2. Activer: Authentication (Phone), Firestore, Storage, Messaging,
//              Analytics, Crashlytics
//  3. Ajouter une app Android (package: com.chofly.app)
//  4. Ajouter une app iOS (bundle: com.chofly.app)
//  5. Installer le CLI: npm install -g firebase-tools
//  6. Installer FlutterFire: dart pub global activate flutterfire_cli
//  7. Lancer: flutterfire configure --project=<votre-project-id>
//     → Ce fichier sera AUTO-GÉNÉRÉ avec vos vraies valeurs
//
//  ⚠️  SÉCURITÉ:
//  - Ne jamais committer ce fichier avec de vraies clés
//  - Ajouter `lib/firebase_options.dart` à .gitignore
//  - Utiliser des Firebase App Check rules en production
//
// ══════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('CHOFLY ne supporte pas le web pour l\'instant.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Plateforme non supportée: $defaultTargetPlatform. '
          'CHOFLY supporte Android et iOS uniquement.',
        );
    }
  }

  // ── Android ─────────────────────────────────────────────────
  // Remplacer par les vraies valeurs après `flutterfire configure`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'YOUR_ANDROID_API_KEY',
    appId:             'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    databaseURL:       null,
  );

  // ── iOS ──────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'YOUR_IOS_API_KEY',
    appId:             'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    iosClientId:       'YOUR_IOS_CLIENT_ID',
    iosBundleId:       'com.chofly.app',
  );
}
