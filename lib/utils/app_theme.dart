import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color bg         = Color(0xFF070B07);
  static const Color bg2        = Color(0xFF0B100B);
  static const Color bg3        = Color(0xFF0F150F);
  static const Color card       = Color(0xFF111811);
  static const Color card2      = Color(0xFF182218);
  static const Color border     = Color(0xFF1C2B1C);
  static const Color border2    = Color(0xFF243624);

  static const Color bgLight    = Color(0xFFF3F9F3);
  static const Color bg2Light   = Color(0xFFEAF4EA);
  static const Color bg3Light   = Color(0xFFE1EFE1);
  static const Color cardLight  = Color(0xFFFFFFFF);
  static const Color card2Light = Color(0xFFF0F9F0);
  static const Color borderLight  = Color(0xFFCCE5CC);
  static const Color border2Light = Color(0xFFB5D6B5);

  static const Color green      = Color(0xFF2DD36F);
  static const Color greenDark  = Color(0xFF1A8C4A);
  static const Color greenLight = Color(0xFF72EFA4);
  static const Color greenDim   = Color(0x142DD36F);
  static const Color greenBorder= Color(0x302DD36F);
  static const Color greenGlow  = Color(0x402DD36F);
  static const Color greenMid   = Color(0xFF20A055);

  static const Color textPrimary   = Color(0xFFE6F2E6);
  static const Color textSecondary = Color(0xFF7A9A7A);
  static const Color textMuted     = Color(0xFF3D5A3D);

  static const Color textPrimaryLight   = Color(0xFF0A180A);
  static const Color textSecondaryLight = Color(0xFF356535);
  static const Color textMutedLight     = Color(0xFF6E9A6E);

  static const Color red       = Color(0xFFFF5C5C);
  static const Color redDim    = Color(0x1AFF5C5C);
  static const Color redBorder = Color(0x40FF5C5C);
  static const Color redBanner = Color(0xD9FF5C5C);
  static const Color yellow    = Color(0xFFFFCC48);
  static const Color blue      = Color(0xFF5BA8FF);
  static const Color orange    = Color(0xFFFF9340);

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD36F), Color(0xFF1A8C4A)],
  );
  static const LinearGradient greenGradientH = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2DD36F), Color(0xFF20A055)],
  );
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF162216), Color(0xFF101810)],
  );

  static List<BoxShadow> get greenGlowShadow => const [
    BoxShadow(color: Color(0x502DD36F), blurRadius: 20, spreadRadius: -2),
    BoxShadow(color: Color(0x202DD36F), blurRadius: 40),
  ];
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static ThemeData get dark  => _build(true);
  static ThemeData get light => _build(false);

  static ThemeData _build(bool isDark) {
    final sc  = isDark ? bg       : bgLight;
    final su  = isDark ? bg2      : bg2Light;
    final cc  = isDark ? card     : cardLight;
    final pt  = isDark ? textPrimary    : textPrimaryLight;
    final st  = isDark ? textSecondary  : textSecondaryLight;
    final ht  = isDark ? textMuted      : textMutedLight;
    final bc  = isDark ? border         : borderLight;
    final br  = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: br,
      scaffoldBackgroundColor: sc,
      colorScheme: ColorScheme(
        brightness: br, primary: green, secondary: greenDark,
        surface: su, background: sc, error: red,
        onPrimary: isDark ? bg : Colors.white, onSecondary: isDark ? bg : Colors.white,
        onSurface: pt, onBackground: pt, onError: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(TextTheme(
        displayLarge:  TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: pt, letterSpacing: -1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: pt, letterSpacing: -0.8),
        displaySmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: pt, letterSpacing: -0.4),
        headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: pt),
        headlineMedium:TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: pt),
        headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: pt),
        bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: pt, height: 1.5),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: st, height: 1.5),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: ht),
        labelLarge:    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? bg : Colors.white, letterSpacing: 0.2),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: sc, elevation: 0, scrolledUnderElevation: 0,
        centerTitle: false, iconTheme: IconThemeData(color: pt),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarColor: Colors.transparent,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: green, foregroundColor: isDark ? bg : Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: green, side: BorderSide(color: bc, width: 1.5),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: cc,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: bc)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: bc)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: green, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: red)),
        hintStyle: TextStyle(color: ht, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? bg3 : bg3Light, selectedItemColor: green,
        unselectedItemColor: ht, showSelectedLabels: true, showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: bc, thickness: 1),
      cardTheme: CardTheme(
        color: cc, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: bc)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? card2 : cardLight,
        contentTextStyle: TextStyle(color: pt, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating, elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? green : ht),
        trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? greenBorder : bc),
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'chofly_theme_mode';
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get themeMode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  ThemeProvider() { _loadFromPrefs(); }
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefKey) == 'light') { _mode = ThemeMode.light; notifyListeners(); }
  }
  Future<void> _saveToPrefs() async {
    (await SharedPreferences.getInstance()).setString(_prefKey, isDark ? 'dark' : 'light');
  }
  void toggle()   { _mode = isDark ? ThemeMode.light : ThemeMode.dark; notifyListeners(); _saveToPrefs(); }
  void setDark()  { _mode = ThemeMode.dark;  notifyListeners(); _saveToPrefs(); }
  void setLight() { _mode = ThemeMode.light; notifyListeners(); _saveToPrefs(); }
}

class AppSpacing {
  static const double xs=4, sm=8, md=16, lg=24, xl=32, xxl=48;
}
class AppRadius {
  static const double sm=8, md=12, lg=16, xl=20, xxl=28, pill=100;
}
