# CHOFLY — Guide de mise en service post-reconstruction

## 1. Prérequis locaux

```bash
flutter --version        # >= 3.x stable
java -version            # Java 17 (requis pour AGP 8.x)
dart --version           # >= 3.0.0
```

## 2. Étapes obligatoires AVANT le premier build

### A. Configurer Firebase
```bash
# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Dans le répertoire du projet
flutterfire configure --project=<votre-firebase-project-id>
# → génère automatiquement lib/firebase_options.dart
# → génère android/app/google-services.json
# → génère ios/Runner/GoogleService-Info.plist
```

### B. Placer google-services.json
```
android/app/google-services.json   ← depuis Firebase Console
```

### C. Ajouter une Google Maps API Key
Dans `android/app/src/main/AndroidManifest.xml`, remplacer :
```
YOUR_GOOGLE_MAPS_API_KEY
```
Par votre clé API Maps Android.

### D. Créer local.properties (ne JAMAIS committer)
```bash
# android/local.properties
flutter.sdk=/path/to/your/flutter/sdk
flutter.versionCode=2
flutter.versionName=2.1.0
```

## 3. Commandes de validation

```bash
# Nettoyer
flutter clean

# Résoudre dépendances
flutter pub get

# Analyse statique (doit passer sans erreurs)
flutter analyze

# Tests
flutter test

# Build APK debug (validation rapide)
flutter build apk --debug

# Build APK release (sans keystore = debug signing auto)
flutter build apk --release

# Build App Bundle Play Store
flutter build appbundle --release
```

## 4. Signing Android (release)

```bash
# Générer un keystore
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

# Renseigner android/key.properties avec les mêmes valeurs
```

## 5. Codemagic — Variables d'environnement à créer

| Groupe | Variable | Contenu |
|---|---|---|
| `firebase_credentials` | `GOOGLE_SERVICES_JSON` | `cat android/app/google-services.json \| base64` |
| `android_signing_props` | `CM_KEY_ALIAS` | alias du keystore |
| `android_signing_props` | `CM_KEY_PASSWORD` | mot de passe clé |
| `android_signing_props` | `CM_KEYSTORE_PASSWORD` | mot de passe keystore |
| `google_play_credentials` | `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | JSON compte de service |

## 6. Structure finale reconstruite

```
chofly/
├── android/
│   ├── app/
│   │   ├── build.gradle          ✅ CORRIGÉ (signingConfigs + crashlytics)
│   │   ├── proguard-rules.pro    ✅ COMPLET
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   ✅ (existant)
│   │       ├── kotlin/com/chofly/app/
│   │       │   └── MainActivity.kt   ✅ CRÉÉ
│   │       └── res/
│   │           ├── drawable/launch_background.xml   ✅ CRÉÉ
│   │           ├── values/styles.xml                ✅ CRÉÉ
│   │           ├── values/colors.xml                ✅ CRÉÉ
│   │           └── xml/network_security_config.xml  ✅ CRÉÉ
│   ├── build.gradle              ✅ CORRIGÉ (+crashlytics classpath)
│   ├── gradle.properties         ✅ CRÉÉ (AndroidX activé)
│   ├── settings.gradle           ✅ CRÉÉ
│   ├── gradlew                   ✅ CRÉÉ (+chmod +x)
│   ├── gradlew.bat               ✅ CRÉÉ
│   ├── gradle/wrapper/
│   │   └── gradle-wrapper.properties  ✅ CRÉÉ (Gradle 8.4)
│   └── key.properties            ✅ TEMPLATE (ne pas committer)
├── ios/
│   ├── Podfile                   ✅ CRÉÉ (iOS 13+)
│   ├── Runner.xcodeproj/
│   │   ├── project.pbxproj       ✅ CRÉÉ
│   │   └── xcshareddata/xcschemes/Runner.xcscheme  ✅ CRÉÉ
│   ├── Runner.xcworkspace/
│   │   └── contents.xcworkspacedata  ✅ CRÉÉ
│   ├── Flutter/
│   │   ├── AppFrameworkInfo.plist  ✅ CRÉÉ
│   │   ├── Debug.xcconfig          ✅ CRÉÉ
│   │   └── Release.xcconfig        ✅ CRÉÉ
│   └── Runner/
│       ├── AppDelegate.swift            ✅ CRÉÉ
│       ├── Runner-Bridging-Header.h     ✅ CRÉÉ
│       ├── GeneratedPluginRegistrant.h  ✅ STUB
│       ├── Info.plist                   ✅ (existant)
│       ├── Base.lproj/
│       │   ├── LaunchScreen.storyboard  ✅ CRÉÉ
│       │   └── Main.storyboard          ✅ CRÉÉ
│       └── Assets.xcassets/             ✅ CRÉÉ
├── lib/                          ✅ INTOUCHÉ (code métier préservé)
├── .gitignore                    ✅ CRÉÉ (professionnel)
├── analysis_options.yaml         ✅ CRÉÉ
├── codemagic.yaml                ✅ CRÉÉ (3 workflows)
├── pubspec.yaml                  ✅ (existant)
└── README_SETUP.md               ✅ CE FICHIER
```
