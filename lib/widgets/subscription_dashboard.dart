import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_model.dart';
import '../../services/firebase_service.dart';
import '../../services/providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// SUBSCRIPTION DASHBOARD — Usage counter [Feature #11]
// ════════════════════════════════════════════════════════════════
class SubscriptionDashboardWidget extends StatelessWidget {
  const SubscriptionDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid ?? '';

    return StreamBuilder<SubscriptionModel?>(
      stream: SubscriptionService().watchSubscription(uid),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final sub = snap.data!;
        final plan = SubscriptionModel.plans[sub.plan];
        final included = (plan?['interventionsPerMonth'] as int?) ?? 999;
        final used = sub.interventionsUsed;
        final remaining = (included - used).clamp(0, included);
        final isUnlimited = sub.plan == SubscriptionPlan.annual;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.greenBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Text('🏠', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('Foyer Protégé',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.greenDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sub.plan == SubscriptionPlan.monthly ? 'Mensuel' : 'Annuel',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: AppTheme.green),
                ),
              ),
            ]),

            const SizedBox(height: 14),

            // Usage display
            if (isUnlimited)
              const Row(children: [
                Icon(Icons.all_inclusive_rounded, size: 20, color: AppTheme.green),
                SizedBox(width: 8),
                Text('Interventions illimitées ce mois',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ])
            else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'Interventions restantes',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  '$remaining / $included',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: remaining == 0 ? AppTheme.red : AppTheme.green,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: included > 0 ? remaining / included : 0,
                  minHeight: 8,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(
                    remaining == 0
                        ? AppTheme.red
                        : remaining == 1
                            ? AppTheme.yellow
                            : AppTheme.green,
                  ),
                ),
              ),
              if (remaining == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Quota mensuel épuisé — renouvellement automatique.',
                    style: TextStyle(fontSize: 11, color: AppTheme.red),
                  ),
                ),
            ],

            const SizedBox(height: 12),

            // Next billing
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                'Prochain renouvellement : ${_formatDate(sub.nextBillingDate)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ]),
          ]),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
