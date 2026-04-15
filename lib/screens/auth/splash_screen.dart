import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/providers.dart';
import '../../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logo;
  late final AnimationController _rings;
  late final AnimationController _text;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();

    _logo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
    _text  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _logoFade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logo, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: _logo, curve: Curves.easeOutBack));
    _ring1     = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _rings, curve: const Interval(0, 0.7, curve: Curves.easeOut)));
    _ring2     = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _rings, curve: const Interval(0.3, 1, curve: Curves.easeOut)));
    _textFade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _text, curve: Curves.easeOut));
    _textSlide = Tween<double>(begin: 16, end: 0).animate(CurvedAnimation(parent: _text, curve: Curves.easeOut));

    _logo.forward().then((_) => _text.forward());
    Future.delayed(const Duration(milliseconds: 2200), _navigate);
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated && auth.userModel == null) {
      for (var i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        if (context.read<AuthProvider>().userModel != null) break;
      }
    }
    if (!mounted) return;
    final a = context.read<AuthProvider>();
    if (a.isAuthenticated && a.userModel != null) {
      if (a.isAdmin)         Navigator.of(context).pushReplacementNamed('/admin');
      else if (a.isProvider) Navigator.of(context).pushReplacementNamed('/provider/home');
      else                   Navigator.of(context).pushReplacementNamed('/customer/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override void dispose() {
    _logo.dispose(); _rings.dispose(); _text.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        // Background geometric pattern
        Positioned.fill(child: CustomPaint(painter: _BgPainter())),

        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Animated rings + logo
          AnimatedBuilder(
            animation: Listenable.merge([_logo, _rings]),
            builder: (_, __) {
              return SizedBox(
                width: 200, height: 200,
                child: Stack(alignment: Alignment.center, children: [
                  // Ring 2 (outer)
                  Opacity(
                    opacity: (1 - _ring2.value).clamp(0, 1),
                    child: Transform.scale(
                      scale: 0.7 + _ring2.value * 0.8,
                      child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.green.withOpacity(0.15 * (1 - _ring2.value)), width: 1),
                        ),
                      ),
                    ),
                  ),
                  // Ring 1 (inner)
                  Opacity(
                    opacity: (1 - _ring1.value * 0.9).clamp(0, 1),
                    child: Transform.scale(
                      scale: 0.5 + _ring1.value * 0.5,
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.green.withOpacity(0.25 * (1 - _ring1.value)), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          gradient: AppTheme.greenGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: AppTheme.greenGlowShadow,
                        ),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('✦', style: TextStyle(fontSize: 30, color: Colors.white, height: 1)),
                        ])),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),

          const SizedBox(height: 20),

          // App name + tagline
          AnimatedBuilder(
            animation: _text,
            builder: (_, __) => FadeTransition(
              opacity: _textFade,
              child: Transform.translate(
                offset: Offset(0, _textSlide.value),
                child: Column(children: [
                  const Text('CHOFLY', style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary, letterSpacing: 5,
                  )),
                  const SizedBox(height: 6),
                  ShaderMask(
                    shaderCallback: (b) => AppTheme.greenGradientH.createShader(b),
                    child: const Text('Services à domicile', style: TextStyle(
                      fontSize: 13, color: Colors.white, letterSpacing: 1.5, fontWeight: FontWeight.w500,
                    )),
                  ),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 64),

          // Progress line
          AnimatedBuilder(
            animation: _rings,
            builder: (_, __) => Container(
              width: 48, height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  colors: const [AppTheme.green, Colors.transparent],
                  stops: [_rings.value, _rings.value],
                ),
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.green.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Corner accent lines
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width * 0.15, size.height * 0.2), paint);
    canvas.drawLine(Offset(size.width * 0.85, size.height * 0.8), Offset(size.width, size.height * 0.8), paint);
    paint.color = AppTheme.green.withOpacity(0.03);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), 60, paint);
  }
  @override bool shouldRepaint(_) => false;
}
