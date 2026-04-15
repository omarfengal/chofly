import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// REFERRAL SCREEN  [Feature #10 — Parrainage]
// ════════════════════════════════════════════════════════════════
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _referralService = ReferralService();
  final _analyticsService = AnalyticsService();

  String? _code;
  int _balance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    final results = await Future.wait([
      _referralService.getReferralCode(uid),
      _referralService.getWalletBalance(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _code = results[0] as String;
      _balance = results[1] as int;
      _isLoading = false;
    });
  }

  Future<void> _share() async {
    if (_code == null) return;
    await _analyticsService.logReferralSent();
    await Share.share(
      '🔧 Essaie CHOFLY — des artisans qualifiés chez toi en moins de 2h !\n'
      'Utilise mon code parrainage : $_code\n'
      'Tu bénéficies d\'une réduction et je reçois 500 DA. chofly.dz',
      subject: 'CHOFLY — Mon code parrainage',
    );
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copié ! ✓'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Parrainage'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.green)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // ── Hero ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.greenDark, Color(0xFF0D6B33)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(children: [
                    const Text('🎁', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      'Parrainez un ami,\ngagnez 500 DA',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white, height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chaque ami parrainé qui passe sa\n1ère commande vous rapporte 500 DA.',
                      style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Wallet balance ────────────────────────────
                if (_balance > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.greenDim,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.greenBorder),
                    ),
                    child: Row(children: [
                      const Text('💰', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Votre crédit', style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                        Text('$_balance DA',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                              color: AppTheme.green)),
                      ]),
                    ]),
                  ),

                if (_balance > 0) const SizedBox(height: 16),

                // ── Code card ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(children: [
                    const Text('Votre code parrainage',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    // Code display
                    GestureDetector(
                      onTap: _copyCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.card2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border2, width: 1.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            _code ?? '—',
                            style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: AppTheme.green, letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.copy_rounded, size: 18, color: AppTheme.textMuted),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Appuyez pour copier',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 16),
                    ChoflyButton(
                      label: '📤 Partager mon code',
                      onPressed: _share,
                      icon: Icons.share_rounded,
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── How it works ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Comment ça marche ?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 14),
                    _Step(num: '1', text: 'Partagez votre code avec un ami'),
                    _Step(num: '2', text: 'Votre ami s\'inscrit et entre votre code'),
                    _Step(num: '3', text: 'Dès sa 1ère commande, vous recevez 500 DA'),
                    _Step(num: '4', text: 'Votre ami profite d\'une réduction sur sa 1ère intervention'),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── My referrals list ─────────────────────────
                const SectionHeader(title: 'Mes parrainages'),
                const SizedBox(height: 12),
                StreamBuilder<List<ReferralModel>>(
                  stream: _referralService.watchReferrals(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Column(children: [SkeletonCard()]);
                    }
                    final refs = snap.data ?? [];
                    if (refs.isEmpty) {
                      return const EmptyState(
                        emoji: '👥',
                        title: 'Aucun parrainage',
                        subtitle: 'Invitez vos amis pour gagner des crédits',
                      );
                    }
                    return Column(
                      children: refs.map((r) => _ReferralTile(referral: r)).toList(),
                    );
                  },
                ),

                const SizedBox(height: 30),
              ]),
            ),
    );
  }
}

class _Step extends StatelessWidget {
  final String num, text;
  const _Step({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(color: AppTheme.greenDim, shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.green))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(
            fontSize: 13, color: AppTheme.textSecondary))),
      ]),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  final ReferralModel referral;
  const _ReferralTile({required this.referral});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.card2,
          child: Text(referral.refereeName[0].toUpperCase(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(referral.refereeName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
          Text(referral.refereePhone,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: referral.isCompleted ? AppTheme.greenDim : AppTheme.card2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              referral.isCompleted ? '+${referral.rewardDA} DA' : 'En attente',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: referral.isCompleted ? AppTheme.green : AppTheme.textMuted,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
