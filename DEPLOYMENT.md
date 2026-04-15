# CHOFLY v2 — Guide de déploiement complet

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ÉTAPE 1 — PRÉREQUIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

flutter doctor          # tout doit être vert
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ÉTAPE 2 — FIREBASE SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Créer projet sur console.firebase.google.com
# Activer: Authentication (Phone), Firestore, Storage, Cloud Messaging
# Région: europe-west1

flutterfire configure   # génère firebase_options.dart

firebase deploy --only firestore
firebase deploy --only storage
cd functions && npm install && cd ..
firebase deploy --only functions

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ÉTAPE 3 — BUILD ANDROID
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Créer keystore (une seule fois)
keytool -genkey -v \
  -keystore ~/chofly-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias chofly

# Créer android/key.properties (NE PAS commiter)
storePassword=<password>
keyPassword=<password>
keyAlias=chofly
storeFile=<path>/chofly-release.jks

# Build
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab

flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ÉTAPE 4 — BUILD IOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cd ios && pod install && cd ..
open ios/Runner.xcworkspace
# → Xcode: Runner → Signing & Capabilities → votre Team
flutter build ipa --release

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ÉTAPE 5 — PREMIER ADMIN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Dans Firestore Console, manuellement:
# users/{uid} → role: "admin"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## CHECKLIST FINALE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FIREBASE
[ ] Règles Firestore déployées (10 indexes + security rules)
[ ] 6 Cloud Functions déployées
[ ] Authentication Phone activée

APPLICATION
[ ] firebase_options.dart avec vrai projet
[ ] Google Maps API key configurée
[ ] flutter pub get sans erreurs
[ ] Test sur device Android réel
[ ] debugShowCheckedModeBanner: false

SÉCURITÉ
[ ] Role escalation bloquée (Firestore rules)
[ ] finalPrice validé côté règles
[ ] Rate limit 3 demandes (Cloud Function)
[ ] Timeout 45 min (Cloud Function scheduled)

UX
[ ] TrustBar visible sur accueil
[ ] Badge CHOFLY Vérifié sur artisans
[ ] Timeline sur l'écran de suivi
[ ] Skeleton loaders sur toutes les listes
[ ] Messages erreur réseau
[ ] Validation numéro algérien 05/06/07
[ ] "< 2h garantie" partout (pas "30 min")

BUSINESS
[ ] Foyer Protégé opérationnel
[ ] Notifications push tous statuts
[ ] Rating atomique (ratingTotal/ratingCount)
[ ] Persistance offline activée

CONTENU À REMPLACER
[ ] wa.me/213XXXXXXXXX → vrai numéro WhatsApp CHOFLY
[ ] Ajouter logo dans assets/images/
[ ] Configurer icônes app Android + iOS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## COMMANDES UTILES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

firebase functions:log --follow        # logs temps réel
firebase deploy --only firestore:rules # update règles sans rebuild
firebase deploy --only functions       # update fonctions sans rebuild
flutter analyze                        # vérifier erreurs Dart
