// lib/screens/customer/customer_orders_screen.dart
// FIX: was empty — now fully implemented

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_extensions.dart';
import '../../widgets/common_widgets.dart';
import '../../config/app_config.dart';

// ════════════════════════════════════════════════════════════════
// CUSTOMER ORDERS SCREEN
// ════════════════════════════════════════════════════════════════
class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _requestService = RequestService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().firebaseUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Mes demandes', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
        )),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.green,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppTheme.green,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'En cours'),
            Tab(text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveRequestsList(service: _requestService, uid: uid),
          _AllRequestsList(service: _requestService, uid: uid),
        ],
      ),
    );
  }
}

class _ActiveRequestsList extends StatelessWidget {
  final RequestService service;
  final String uid;
  const _ActiveRequestsList({required this.service, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequest>>(
      stream: service.getActiveCustomerRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [SkeletonCard(), SkeletonCard(), SkeletonCard()]),
          );
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(child: EmptyState(
            emoji: '✅',
            title: 'Aucune demande en cours',
            subtitle: 'Vos missions actives apparaîtront ici',
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) => RequestCard(
            request: requests[i],
            onTap: () => Navigator.of(context).pushNamed(
              '/customer/request-detail',
              arguments: requests[i].id,
            ),
          ),
        );
      },
    );
  }
}

class _AllRequestsList extends StatelessWidget {
  final RequestService service;
  final String uid;
  const _AllRequestsList({required this.service, required this.uid});

  // Amélioration 6: pull-to-refresh key
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequest>>(
      stream: service.getCustomerRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [SkeletonCard(), SkeletonCard(), SkeletonCard()]),
          );
        }
        if (snapshot.hasError) {
          return ErrorBanner(message: 'Erreur de chargement');
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return RefreshIndicator(
            key: _refreshKey,
            color: AppTheme.green,
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 400)),
            child: ListView(children: const [
              Center(child: EmptyState(
                emoji: '📋',
                title: 'Aucune demande',
                subtitle: 'Votre historique apparaîtra ici',
              )),
            ]),
          );
        }
        return RefreshIndicator(
          key: _refreshKey,
          color: AppTheme.green,
          onRefresh: () async => await Future.delayed(const Duration(milliseconds: 400)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (_, i) => RequestCard(
              request: requests[i],
              onTap: () => Navigator.of(context).pushNamed(
                '/customer/request-detail',
                arguments: requests[i].id,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CUSTOMER PROFILE SCREEN
// ════════════════════════════════════════════════════════════════
class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Mon profil', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
        )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Avatar + name ──────────────────────────────────
          Center(child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.greenDim,
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.green),
              ),
            ),
            const SizedBox(height: 14),
            Text(user?.name ?? '', style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
            )),
            const SizedBox(height: 4),
            Text(user?.phone ?? '', style: const TextStyle(
              fontSize: 14, color: AppTheme.textSecondary,
            )),
            const SizedBox(height: 6),
            if (user?.wilaya != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(user!.wilaya!, style: const TextStyle(
                  fontSize: 13, color: AppTheme.textMuted,
                )),
              ]),
          ])),

          const SizedBox(height: 32),

          // ── Stats ──────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatCard(
              value: '${user?.totalOrders ?? 0}',
              label: 'Missions',
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              value: user?.createdAt != null
                ? '${DateTime.now().difference(user!.createdAt).inDays}j'
                : '0j',
              label: 'Membre depuis',
            )),
          ]),

          const SizedBox(height: 24),

          // ── Menu ───────────────────────────────────────────
          const Text('Mon compte', style: TextStyle(
            fontSize: 13, color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600, letterSpacing: .06,
          )),
          const SizedBox(height: 12),

          _ProfileTile(
            icon: Icons.card_giftcard_outlined,
            title: 'Foyer Protégé',
            subtitle: 'Abonnement mensuel',
            onTap: () => Navigator.of(context).pushNamed('/customer/subscription'),
          ),
          _ProfileTile(
            icon: Icons.people_outline_rounded,
            title: 'Parrainage',
            subtitle: 'Invitez vos proches et gagnez des crédits',
            onTap: () => context.showSnack('Bientôt disponible'),
          ),
          _ProfileTile(
            icon: Icons.history_rounded,
            title: 'Historique complet',
            subtitle: 'Toutes vos demandes passées',
            onTap: () => Navigator.of(context).pushNamed('/customer/history'),
          ),
          _ProfileTile(
            icon: Icons.help_outline_rounded,
            title: 'Aide & Support',
            subtitle: 'Contacter CHOFLY',
            onTap: () => _contactSupport(context),
          ),

          const SizedBox(height: 24),

          // ── Danger zone ────────────────────────────────────
          const Text('Zone dangereuse', style: TextStyle(
            fontSize: 13, color: AppTheme.red,
            fontWeight: FontWeight.w600, letterSpacing: .06,
          )),
          const SizedBox(height: 12),

          ChoflyButton(
            label: 'Supprimer mon compte',
            isOutlined: true,
            color: AppTheme.red,
            onPressed: () async {
              final confirm = await context.showConfirmDialog(
                title: 'Supprimer le compte ?',
                message:
                    'Cette action est irréversible.\n\n'
                    'Toutes vos données (commandes, abonnements, crédits) '
                    'seront effacées définitivement.',
                confirmText: 'Supprimer définitivement',
                confirmColor: AppTheme.red,
              );
              if (confirm != true || !context.mounted) return;

              final uid = context.read<AuthProvider>().firebaseUser!.uid;
              try {
                await AuthService().deleteAccount(uid);
                if (context.mounted) {
                  await context.read<AuthProvider>().signOut();
                }
              } catch (e) {
                if (context.mounted) {
                  context.showSnack(
                    'Erreur lors de la suppression. '
                    'Reconnectez-vous et réessayez.',
                  );
                }
              }
            },
          ),

          const SizedBox(height: 12),

          // ── Sign out ───────────────────────────────────────
          ChoflyButton(
            label: 'Se déconnecter',
            isOutlined: true,
            color: AppTheme.red,
            onPressed: () async {
              final confirm = await context.showConfirmDialog(
                title: 'Se déconnecter ?',
                message: 'Vous devrez vous reconnecter pour utiliser CHOFLY.',
                confirmText: 'Déconnecter',
                confirmColor: AppTheme.red,
              );
              if (confirm == true && context.mounted) {
                await auth.signOut();
              }
            },
          ),
        ]),
      ),
    );
  }

  void _contactSupport(BuildContext context) async {
    final url = Uri.parse(AppConfig.customerSupportLink);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      context.showSnack('Impossible d\'ouvrir WhatsApp');
    }
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.green,
        )),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppTheme.card2, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: AppTheme.green),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ])),
          const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}
