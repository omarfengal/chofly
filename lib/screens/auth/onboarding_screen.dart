import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  static const _pages = [
    _PageData(
      gradient: [Color(0xFF0C1C0C), Color(0xFF071207)],
      accentColor: AppTheme.green,
      icon: '⚡',
      iconBg: [Color(0xFF1A3A1A), Color(0xFF0F2A0F)],
      label: 'RAPIDE',
      title: 'Un technicien\nchez vous en 2h',
      subtitle: 'Plomberie, électricité, clim.\nL\'artisan qualifié arrive vite.',
    ),
    _PageData(
      gradient: [Color(0xFF0A1A1E), Color(0xFF070D12)],
      accentColor: Color(0xFF5BA8FF),
      icon: '⭐',
      iconBg: [Color(0xFF142030), Color(0xFF0A1520)],
      label: 'FIABLE',
      title: 'Artisans vérifiés\net notés',
      subtitle: 'Chaque technicien est contrôlé.\nVraies évaluations clients.',
    ),
    _PageData(
      gradient: [Color(0xFF1A1408), Color(0xFF0F0C05)],
      accentColor: Color(0xFFFFCC48),
      icon: '💵',
      iconBg: [Color(0xFF2A2010), Color(0xFF1A1408)],
      label: 'SIMPLE',
      title: 'Cash après\nl\'intervention',
      subtitle: 'Pas de carte, pas de compte.\nPaiement direct au technicien.',
    ),
  ];

  @override void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    _slide = Tween<double>(begin: 24, end: 0).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    _entry.forward();
  }
  @override void dispose() { _pageCtrl.dispose(); _entry.dispose(); super.dispose(); }

  void _onPage(int i) {
    setState(() => _page = i);
    _entry.reset();
    _entry.forward();
  }

  @override Widget build(BuildContext context) {
    final pg = _pages[_page];
    final isLast = _page == _pages.length - 1;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: pg.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            // Background abstract geometry
            Positioned.fill(child: CustomPaint(painter: _PageBgPainter(pg.accentColor, _page))),

            Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  // Page counter
                  Text('${_page + 1} / ${_pages.length}', style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1,
                  )),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text('Passer', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500,
                    )),
                  ),
                ]),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: _onPage,
                  itemCount: _pages.length,
                  itemBuilder: (ctx, i) => _OnboardingPage(data: _pages[i], anim: i == _page ? _entry : null),
                ),
              ),

              // Dots
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) {
                final active = _page == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: active ? AppTheme.greenGradientH : null,
                    color: active ? null : AppTheme.border2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              })),

              const SizedBox(height: 36),

              // CTA buttons
              AnimatedBuilder(
                animation: _entry,
                builder: (_, __) => FadeTransition(
                  opacity: _fade,
                  child: Transform.translate(
                    offset: Offset(0, _slide.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(children: [
                        if (isLast) ...[
                          ChoflyButton(
                            label: 'Commencer maintenant',
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                          ),
                          const SizedBox(height: 10),
                          ChoflyButton(
                            label: 'Je suis artisan →',
                            isOutlined: true,
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/login', arguments: 'provider'),
                          ),
                        ] else
                          ChoflyButton(
                            label: 'Suivant',
                            onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  final AnimationController? anim;
  const _OnboardingPage({required this.data, this.anim});

  @override Widget build(BuildContext context) {
    final fade  = anim != null ? Tween<double>(begin:0,end:1).animate(CurvedAnimation(parent:anim!, curve:Curves.easeOut)) : null;
    final slide = anim != null ? Tween<double>(begin:32,end:0).animate(CurvedAnimation(parent:anim!, curve:Curves.easeOut)) : null;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Icon with layered rings
        SizedBox(width: 150, height: 150, child: Stack(alignment: Alignment.center, children: [
          Container(width: 150, height: 150, decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: data.accentColor.withOpacity(0.08), width: 1),
          )),
          Container(width: 110, height: 110, decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: data.accentColor.withOpacity(0.14), width: 1.5),
          )),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.iconBg),
              shape: BoxShape.circle,
              border: Border.all(color: data.accentColor.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: data.accentColor.withOpacity(0.25), blurRadius: 24, spreadRadius: -4)],
            ),
            child: Center(child: Text(data.icon, style: const TextStyle(fontSize: 36))),
          ),
        ])),

        const SizedBox(height: 36),

        // Label pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: data.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: data.accentColor.withOpacity(0.3)),
          ),
          child: Text(data.label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: data.accentColor, letterSpacing: 2,
          )),
        ),

        const SizedBox(height: 16),

        Text(data.title, style: const TextStyle(
          fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
          height: 1.15, letterSpacing: -0.5,
        ), textAlign: TextAlign.center),

        const SizedBox(height: 14),

        Text(data.subtitle, style: const TextStyle(
          fontSize: 15, color: AppTheme.textSecondary, height: 1.65,
        ), textAlign: TextAlign.center),
      ]),
    );

    if (fade != null && slide != null) {
      return AnimatedBuilder(
        animation: anim!,
        builder: (_, child) => FadeTransition(
          opacity: fade,
          child: Transform.translate(offset: Offset(0, slide.value), child: child),
        ),
        child: content,
      );
    }
    return content;
  }
}

class _PageData {
  final List<Color> gradient, iconBg;
  final Color accentColor;
  final String icon, label, title, subtitle;
  const _PageData({required this.gradient, required this.accentColor, required this.icon,
    required this.iconBg, required this.label, required this.title, required this.subtitle});
}

class _PageBgPainter extends CustomPainter {
  final Color accent;
  final int page;
  const _PageBgPainter(this.accent, this.page);

  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = accent.withOpacity(0.04)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    // Top-right arc
    canvas.drawArc(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.6), math.pi * 0.5, math.pi * 0.5, false, p);
    // Bottom-left arc
    canvas.drawArc(Rect.fromCircle(center: Offset(0, size.height), radius: size.height * 0.4), -math.pi * 0.5, math.pi * 0.5, false, p);
    // Diagonal line accent
    p.color = accent.withOpacity(0.03);
    p.strokeWidth = 40;
    p.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * 0.6, 0), Offset(size.width * 1.1, size.height * 0.5), p);
  }
  @override bool shouldRepaint(covariant _PageBgPainter old) => old.page != page;
}
