import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_extensions.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/subscription_dashboard.dart';

// ════════════════════════════════════════════════════════════════
// CUSTOMER HOME SCREEN  [#6 SliverGrid dynamique]
// ════════════════════════════════════════════════════════════════
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _requestService = RequestService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────
            SliverToBoxAdapter(child: _Header(user: user)),

            // ── Trust bar ────────────────────────────────────
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TrustBar(),
            )),

            // ── Artisans disponibles (TÂCHE 2) ─────────────────
            SliverToBoxAdapter(child: _AvailableProvidersBadge(user: user)),

            // ── Hero CTA ─────────────────────────────────────
            SliverToBoxAdapter(child: _HeroBanner()),

            // ── Subscription usage (si abonné) ───────────────
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.only(top: 14),
              child: SubscriptionDashboardWidget(),
            )),

            // ── Services grid [#6 — dynamique SliverGrid] ────
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: SectionHeader(title: 'Services'),
            )),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = ServiceCategory.values[index];
                    final data = ServiceData.categories[cat]!;
                    return _ServiceTile(category: cat, data: data);
                  },
                  childCount: ServiceCategory.values.length,
                ),
              ),
            ),

            // ── Promo banner ────────────────────────────────
            SliverToBoxAdapter(child: _SubscriptionPromo()),

            // ── Parrainage promo ────────────────────────────
            SliverToBoxAdapter(child: _ReferralPromo()),

            // ── Recent requests ──────────────────────────────
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: SectionHeader(title: 'Demandes récentes'),
            )),
            SliverToBoxAdapter(
              child: _RecentRequests(service: _requestService, auth: auth)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserModel? user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Bonjour ${user?.name.split(' ').first ?? ''} 👋',
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.green),
              const SizedBox(width: 3),
              Text(user?.wilaya ?? 'Algérie', style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
              )),
            ]),
          ]),
          Row(children: [
            // [#2] Theme toggle
            _ThemeToggle(),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/customer/profile'),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.card2,
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.green),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Theme toggle button [#2] ──────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: tp.toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            tp.isDark ? '☀️' : '🌙',
            style: const TextStyle(fontSize: 17),
          ),
        ),
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/customer/new-request'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.greenDark, Color(0xFF0D6B33)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Besoin d\'un artisan ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Technicien chez vous en moins de 2h garantie',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Demander maintenant',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.greenDark)),
                SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, size: 13, color: AppTheme.greenDark),
              ]),
            ),
          ])),
          const SizedBox(width: 10),
          const Text('🔧', style: TextStyle(fontSize: 48)),
        ]),
      ),
    );
  }
}

// ── Service tile [#6 — fonctionne pour N catégories] ──────────
class _ServiceTile extends StatelessWidget {
  final ServiceCategory category;
  final Map<String, dynamic> data;
  const _ServiceTile({required this.category, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .pushNamed('/customer/new-request', arguments: category),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.card : AppTheme.cardLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppTheme.border : AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data['icon'] as String, style: const TextStyle(fontSize: 28)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['label'] as String, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
              )),
              Text('Dès ${(data['priceMin'] as int).formattedDA}', style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Subscription promo ────────────────────────────────────────
class _SubscriptionPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/customer/subscription'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border2),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.greenDim, borderRadius: BorderRadius.circular(6)),
            child: const Text('NOUVEAU', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: AppTheme.green, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text(
            'Foyer Protégé — Maintenance mensuelle à prix fixe',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          )),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

// ── Referral promo [#10] ──────────────────────────────────────
class _ReferralPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/customer/referral'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const Text('🎁', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parrainez un ami', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Gagnez 500 DA à chaque parrainage',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          )),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

// ── Recent requests ───────────────────────────────────────────
class _RecentRequests extends StatefulWidget {
  final RequestService service;
  final AuthProvider auth;
  const _RecentRequests({required this.service, required this.auth});
  @override
  State<_RecentRequests> createState() => _RecentRequestsState();
}

class _RecentRequestsState extends State<_RecentRequests> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: StreamBuilder<List<ServiceRequest>>(
        stream: widget.service.getCustomerRequests(
            widget.auth.firebaseUser?.uid ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [SkeletonCard(), SkeletonCard()]),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ErrorBanner(
                message: 'Impossible de charger les demandes',
                onRetry: () => setState(() {}),
              ),
            );
          }
          final requests = (snapshot.data ?? []).take(3).toList();
          if (requests.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: EmptyState(
                emoji: '📋',
                title: 'Aucune demande',
                subtitle: 'Vos demandes de service apparaîtront ici',
              ),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: requests.length + 1, // +1 for "voir tout" button
            itemBuilder: (context, i) {
              if (i == requests.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/customer/orders'),
                    child: const Text('Voir toutes les demandes →',
                      style: TextStyle(fontSize: 13, color: AppTheme.green,
                        fontWeight: FontWeight.w600)),
                  ),
                );
              }
              return RequestCard(
                request: requests[i],
                onTap: () => Navigator.of(context).pushNamed(
                  '/customer/request-detail',
                  arguments: requests[i].id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}


// TÂCHE 2 — Indicateur d'artisans disponibles en temps réel
class _AvailableProvidersBadge extends StatelessWidget {
  final UserModel? user;
  const _AvailableProvidersBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    final wilaya = user?.wilaya ?? '';
    return StreamBuilder<int>(
      stream: wilaya.isNotEmpty
          ? RequestService().watchAvailableProviders(wilaya)
          : RequestService().watchAvailableProvidersGlobal(),
      builder: (context, snapshot) {
        // Fallback: ne rien afficher si pas encore de données
        if (!snapshot.hasData) return const SizedBox.shrink();
        final count = snapshot.data!;
        if (count == 0) {
          return _buildBadge(context,
            icon: Icons.schedule_rounded,
            color: AppTheme.orange,
            text: 'Disponibilité limitée pour le moment',
            sub: 'Votre demande sera traitée dès que possible',
          );
        }
        return _buildBadge(context,
          icon: Icons.circle,
          color: AppTheme.green,
          text: '$count artisan${count > 1 ? "s" : ""} disponible${count > 1 ? "s" : ""}',
          sub: 'dans votre zone${wilaya.isNotEmpty ? " ($wilaya)" : ""}',
        );
      },
    );
  }

  Widget _buildBadge(BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
    required String sub,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        _LiveDot(color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          Text(sub, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ])),
      ]),
    );
  }
}

// Dot animé "live"
class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({required this.color});
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_anim.value),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: widget.color.withOpacity(0.4),
            blurRadius: 6 * _anim.value,
            spreadRadius: 2 * _anim.value,
          )],
        ),
      ),
    );
  }
}
