// lib/screens/customer/subscription_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../models/subscription_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_extensions.dart';
import '../../widgets/common_widgets.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final _subService = SubscriptionService();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Foyer Protégé'),
      body: StreamBuilder<SubscriptionModel?>(
        stream: _subService.watchSubscription(auth.firebaseUser?.uid ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ChoflyLoader();
          }
          final activeSub = snapshot.data;
          if (activeSub != null) {
            return _ActiveSubscriptionView(sub: activeSub, service: _subService);
          }
          return _SubscriptionPlansView(service: _subService, auth: auth);
        },
      ),
    );
  }
}

// ── Active subscription ───────────────────────────────────────
class _ActiveSubscriptionView extends StatelessWidget {
  final SubscriptionModel sub;
  final SubscriptionService service;
  const _ActiveSubscriptionView({required this.sub, required this.service});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Text('🏠', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(sub.planName, style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
        )),
        const SizedBox(height: 6),
        const Text('Abonnement actif', style: TextStyle(
          fontSize: 14, color: AppTheme.green, fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 28),
        _InfoRow('Prochaine facturation', sub.nextBillingDate.formattedDate),
        _InfoRow('Prix mensuel', sub.monthlyPrice.formattedDA),
        _InfoRow('Visites préventives', '${sub.monthlyVisits}/mois'),
        _InfoRow('Réduction', '-${sub.discountPercent}% sur toutes les missions'),
        if (sub.isPriorityAccess) _InfoRow('Accès prioritaire', 'Inclus ✓'),
        const SizedBox(height: 32),
        ChoflyButton(
          label: 'Annuler l\'abonnement',
          isOutlined: true,
          color: AppTheme.red,
          onPressed: () async {
            final confirm = await context.showConfirmDialog(
              title: 'Annuler l\'abonnement ?',
              message: 'Vous perdrez tous les avantages Foyer Protégé.',
              confirmText: 'Annuler l\'abonnement',
              confirmColor: AppTheme.red,
            );
            if (confirm == true) {
              await service.cancelSubscription(sub.id);
              if (context.mounted) {
                context.showSnack('Abonnement annulé');
                Navigator.of(context).pop();
              }
            }
          },
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ]),
    );
  }
}

// ── Plans view ────────────────────────────────────────────────
class _SubscriptionPlansView extends StatefulWidget {
  final SubscriptionService service;
  final AuthProvider auth;
  const _SubscriptionPlansView({required this.service, required this.auth});

  @override
  State<_SubscriptionPlansView> createState() => _SubscriptionPlansViewState();
}

class _SubscriptionPlansViewState extends State<_SubscriptionPlansView> {
  SubscriptionPlan _selected = SubscriptionPlan.premium;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Protégez votre foyer', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
        )),
        const SizedBox(height: 6),
        const Text(
          'Maintenance préventive mensuelle + réductions exclusives. '
          'Payez en cash lors de la visite mensuelle.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        ...SubscriptionPlan.values.map((plan) {
          final data = SubscriptionModel.plans[plan]!;
          final isSelected = _selected == plan;
          return GestureDetector(
            onTap: () => setState(() => _selected = plan),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.greenDim : AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.green : AppTheme.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (plan == SubscriptionPlan.premium)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('RECOMMANDÉ', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.bg,
                      )),
                    ),
                  Text(data['name'] as String, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: isSelected ? AppTheme.green : AppTheme.textPrimary,
                  )),
                  const SizedBox(height: 4),
                  Text(data['description'] as String, style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary, height: 1.4,
                  )),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text((data['price'] as int).formattedDA, style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: isSelected ? AppTheme.green : AppTheme.textPrimary,
                  )),
                  const Text('/mois', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ]),
              ]),
            ),
          );
        }),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Icon(Icons.info_outline, size: 16, color: AppTheme.yellow, ),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Paiement en cash lors de chaque visite mensuelle. Résiliable à tout moment.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            )),
          ]),
        ),

        const SizedBox(height: 24),
        ChoflyButton(
          label: 'Souscrire — ${(SubscriptionModel.plans[_selected]!['price'] as int).formattedDA}/mois',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : () => _subscribe(context),
        ),
      ]),
    );
  }

  Future<void> _subscribe(BuildContext context) async {
    final planData = SubscriptionModel.plans[_selected]!;

    // Gate de confirmation — engagement paiement cash explicite
    final confirm = await context.showConfirmDialog(
      title: 'Confirmer l\'abonnement',
      message:
          '${planData['name']} — ${(planData['price'] as int).formattedDA}/mois\n\n'
          '⚠️ En confirmant, vous vous engagez à payer en CASH '
          'lors de chaque visite mensuelle.\n\n'
          'L\'abonnement peut être résilié à tout moment depuis votre profil.',
      confirmText: 'Je confirme',
      confirmColor: AppTheme.green,
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    await widget.service.createSubscription(
      customerId: widget.auth.firebaseUser!.uid,
      customerName: widget.auth.userModel!.name,
      plan: _selected,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      context.showSnack('Abonnement activé ! 🎉');
      Navigator.of(context).pop();
    }
  }
}
