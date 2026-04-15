import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_extensions.dart';
// [#4] PromoCode model — already in models.dart via models.dart append

// ════════════════════════════════════════════════════════════════
// ADMIN SCAFFOLD
// ════════════════════════════════════════════════════════════════
class AdminScaffold extends StatefulWidget {
  const AdminScaffold({super.key});

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  int _index = 0;

  final List<Widget> _screens = const [
    AdminDashboard(),
    AdminRequestsScreen(),
    AdminProvidersScreen(),
    AdminCustomersScreen(),
    AdminPromoScreen(),           // [#4] Promo codes
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bg3,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AdminNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard', index: 0, current: _index, onTap: (i) => setState(() => _index = i)),
                _AdminNavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded,
                  label: 'Demandes', index: 1, current: _index, onTap: (i) => setState(() => _index = i)),
                _AdminNavItem(icon: Icons.engineering_outlined, activeIcon: Icons.engineering_rounded,
                  label: 'Artisans', index: 2, current: _index, onTap: (i) => setState(() => _index = i)),
                _AdminNavItem(icon: Icons.group_outlined, activeIcon: Icons.group_rounded,
                  label: 'Clients', index: 3, current: _index, onTap: (i) => setState(() => _index = i)),
                _AdminNavItem(icon: Icons.discount_outlined, activeIcon: Icons.discount_rounded,
                  label: 'Promos', index: 4, current: _index, onTap: (i) => setState(() => _index = i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;

  const _AdminNavItem({required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? activeIcon : icon,
            color: isActive ? AppTheme.green : AppTheme.textMuted, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? AppTheme.green : AppTheme.textMuted,
          )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD
// ════════════════════════════════════════════════════════════════
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Admin Panel', style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
                      )),
                      Text('CHOFLY — Vue d\'ensemble', style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary,
                      )),
                    ],
                  ),
                  TextButton(
                    onPressed: () => auth.signOut(),
                    child: const Text('Déco', style: TextStyle(color: AppTheme.red, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Stats grid
              FutureBuilder<Map<String, int>>(
                future: adminService.getDashboardStats(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Column(children: [SkeletonCard(), SkeletonCard()]);
                  }
                  final stats = snap.data ?? {};
                  return Column(children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _AdminStatCard(value: stats['pendingRequests']?.toString() ?? '—', label: 'En attente', icon: '⏳', color: AppTheme.yellow),
                        _AdminStatCard(value: stats['completedRequests']?.toString() ?? '—', label: 'Terminées', icon: '✅', color: AppTheme.green),
                        _AdminStatCard(value: stats['activeProviders']?.toString() ?? '—', label: 'Artisans actifs', icon: '🔧', color: AppTheme.blue),
                        _AdminStatCard(value: stats['totalCustomers']?.toString() ?? '—', label: 'Clients', icon: '👥', color: AppTheme.orange),
                      ],
                    ),
                    // [#12] Urgent alert if stale requests
                    if ((stats['urgentPending'] ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.redDim, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.redBorder),
                        ),
                        child: Row(children: [
                          const Text('⚠️', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            '${stats['urgentPending']} demande(s) en attente depuis +30 min — intervention requise',
                            style: const TextStyle(fontSize: 12, color: AppTheme.red, fontWeight: FontWeight.w600),
                          )),
                        ]),
                      ),
                    ],
                  ]);
                },
              ),
              const SizedBox(height: 28),
              // Pending providers to approve
              const Text('Artisans en attente', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
              )),
              const SizedBox(height: 12),
              StreamBuilder<List<ProviderModel>>(
                stream: adminService.getPendingProviders(),
                builder: (context, snap) {
                  final providers = snap.data ?? [];
                  if (providers.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        children: [
                          Text('✅', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 12),
                          Text('Aucun artisan en attente', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: providers.map((p) => _PendingProviderCard(provider: p)).toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              // Recent requests
              const Text('Dernières demandes', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
              )),
              const SizedBox(height: 12),
              StreamBuilder<List<ServiceRequest>>(
                stream: adminService.getPendingRequests(),
                builder: (context, snap) {
                  final requests = (snap.data ?? []).take(5).toList();
                  if (requests.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        children: [
                          Text('😌', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 12),
                          Text('Aucune demande en attente', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: requests.map((req) => _AdminRequestRow(request: req)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String value, label, icon;
  final Color color;

  const _AdminStatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingProviderCard extends StatelessWidget {
  final ProviderModel provider;
  const _PendingProviderCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.card2,
            child: Text(provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 18, color: AppTheme.green, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text(provider.skills.join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(provider.wilaya, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Row(
            children: [
              _SmallBtn(label: '✕', color: AppTheme.red, onTap: () async {
                await adminService.blockProvider(provider.uid);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artisan refusé')));
              }),
              const SizedBox(width: 8),
              _SmallBtn(label: '✓', color: AppTheme.green, onTap: () async {
                await adminService.approveProvider(provider.uid);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artisan approuvé ✅')));
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminRequestRow extends StatelessWidget {
  final ServiceRequest request;
  const _AdminRequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminAssignScreen(request: request),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Text(ServiceData.categories[request.category]!['icon'] as String,
              style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${request.customerName} — ${request.categoryLabel}', style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                  )),
                  Text('${request.commune}, ${request.wilaya}', style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted,
                  )),
                ],
              ),
            ),
            StatusBadge(status: request.status),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN ASSIGN SCREEN
// ════════════════════════════════════════════════════════════════
class AdminAssignScreen extends StatelessWidget {
  final ServiceRequest request;
  const AdminAssignScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: ChoflyAppBar(title: 'Assigner un artisan'),
      body: Column(
        children: [
          // Request info
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${request.categoryLabel} — ${request.issueType}', style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                )),
                const SizedBox(height: 6),
                Text('Client: ${request.customerName}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('Adresse: ${request.address}, ${request.wilaya}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('Artisans disponibles', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
            )),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<ProviderModel>>(
              stream: adminService.getAllProviders(),
              builder: (context, snap) {
                final providers = (snap.data ?? []).where((p) => p.isApproved && p.isOnline).toList();
                if (providers.isEmpty) {
                  return const EmptyState(emoji: '😕', title: 'Aucun artisan disponible',
                    subtitle: 'Tous les artisans sont hors ligne');
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: providers.length,
                  itemBuilder: (context, i) {
                    final p = providers[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ProviderCard(
                        provider: p,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppTheme.card,
                              title: Text('Assigner ${p.name} ?', style: const TextStyle(color: AppTheme.textPrimary)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Non', style: TextStyle(color: AppTheme.textMuted))),
                                TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Oui', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await adminService.assignProvider(request.id, p);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${p.name} assigné avec succès ✅'),
                              ));
                              Navigator.of(context).pop();
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN REQUESTS SCREEN
// ════════════════════════════════════════════════════════════════
class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Toutes les demandes', showBack: false),
      body: StreamBuilder<List<ServiceRequest>>(
        stream: adminService.getAllRequests(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.green)));
          }
          final requests = snap.data ?? [];
          if (requests.isEmpty) {
            return const EmptyState(emoji: '📋', title: 'Aucune demande', subtitle: '');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final req = requests[i];
              return GestureDetector(
                onTap: () {
                  if (req.status == RequestStatus.pending) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminAssignScreen(request: req),
                    ));
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(ServiceData.categories[req.category]!['icon'] as String, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(child: Text('${req.customerName} — ${req.categoryLabel}', style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                          ))),
                          StatusBadge(status: req.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${req.address}, ${req.wilaya}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      if (req.providerName != null) ...[
                        const SizedBox(height: 4),
                        Text('Artisan: ${req.providerName}', style: const TextStyle(fontSize: 12, color: AppTheme.green)),
                      ],
                      if (req.status == RequestStatus.pending)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(255, 209, 102, 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Appuyer pour assigner →', style: TextStyle(
                              fontSize: 12, color: AppTheme.yellow, fontWeight: FontWeight.w600,
                            )),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN PROVIDERS SCREEN
// ════════════════════════════════════════════════════════════════
class AdminProvidersScreen extends StatelessWidget {
  const AdminProvidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Artisans', showBack: false),
      body: StreamBuilder<List<ProviderModel>>(
        stream: adminService.getAllProviders(),
        builder: (context, snap) {
          final providers = snap.data ?? [];
          if (providers.isEmpty) return const EmptyState(emoji: '🔧', title: 'Aucun artisan', subtitle: '');
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: providers.length,
            itemBuilder: (context, i) {
              final p = providers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.card2,
                      child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 18, color: AppTheme.green, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            if (p.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 14, color: AppTheme.blue),
                            ],
                          ]),
                          Text(p.skills.join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Row(children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: p.isOnline ? AppTheme.green : AppTheme.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(p.isOnline ? 'En ligne' : 'Hors ligne', style: TextStyle(
                              fontSize: 11, color: p.isOnline ? AppTheme.green : AppTheme.textMuted,
                            )),
                            const SizedBox(width: 10),
                            Text('${p.completedJobs} missions', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ]),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.isApproved ? Color.fromRGBO(46, 204, 113, 0.1) : Color.fromRGBO(255, 209, 102, 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(p.isApproved ? 'Approuvé' : 'En attente', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: p.isApproved ? AppTheme.green : AppTheme.yellow,
                          )),
                        ),
                        if (!p.isApproved) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => adminService.approveProvider(p.uid),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.greenDim,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Color.fromRGBO(46, 204, 113, 0.3)),
                              ),
                              child: const Text('Approuver', style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.green,
                              )),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN CUSTOMERS SCREEN
// ════════════════════════════════════════════════════════════════
class AdminCustomersScreen extends StatelessWidget {
  const AdminCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Clients', showBack: false),
      body: StreamBuilder<List<UserModel>>(
        stream: adminService.getAllCustomers(),
        builder: (context, snap) {
          final users = snap.data ?? [];
          if (users.isEmpty) return const EmptyState(emoji: '👥', title: 'Aucun client', subtitle: '');
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.card2,
                      child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 16, color: AppTheme.green, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          Text(u.phone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text('${u.wilaya ?? '—'} · ${u.totalOrders} demandes', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    if (u.isBlocked)
                      const Text('🚫', style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12), // BUG14 FIX: withOpacity for Flutter compat
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)), // BUG14 FIX
        ),
        child: Center(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16))),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN PROMO CODES SCREEN  [Feature #4]
// ════════════════════════════════════════════════════════════════
class AdminPromoScreen extends StatefulWidget {
  const AdminPromoScreen({super.key});
  @override
  State<AdminPromoScreen> createState() => _AdminPromoScreenState();
}

class _AdminPromoScreenState extends State<AdminPromoScreen> {
  final _promoService = PromoService();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _discountPercent = 10;
  int? _discountFixed;
  int _usageLimit = 100;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 30));
  bool _isCreating = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_codeCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez tous les champs')));
      return;
    }
    setState(() => _isCreating = true);
    final auth = context.read<AuthProvider>();
    await _promoService.createPromo(
      code: _codeCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      discountPercent: _discountFixed == null ? _discountPercent : 0,
      discountFixed: _discountFixed,
      usageLimit: _usageLimit,
      expiresAt: _expiresAt,
      adminId: auth.firebaseUser?.uid ?? '',
    );
    if (!mounted) return;
    setState(() => _isCreating = false);
    _codeCtrl.clear();
    _descCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code promo créé ✓')));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.green)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Codes Promo', showBack: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Create form ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Créer un code', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 14),
              // Code
              TextField(
                controller: _codeCtrl,
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code (ex: ETE2025)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.tag_rounded, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 10),
              // Description
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              // Discount type
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Réduction (%)', style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _StepBtn(label: '−', onTap: () => setState(() {
                      if (_discountPercent > 5) _discountPercent -= 5;
                    })),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$_discountPercent%', style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.green))),
                    _StepBtn(label: '+', onTap: () => setState(() {
                      if (_discountPercent < 50) _discountPercent += 5;
                    })),
                  ]),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Limite d\'utilisation', style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _StepBtn(label: '−', onTap: () => setState(() {
                      if (_usageLimit > 10) _usageLimit -= 10;
                    })),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$_usageLimit', style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                    _StepBtn(label: '+', onTap: () => setState(() => _usageLimit += 10)),
                  ]),
                ])),
              ]),
              const SizedBox(height: 14),
              // Expiry
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.card2, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Text('Expire le ${_expiresAt.day}/${_expiresAt.month}/${_expiresAt.year}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    const Spacer(),
                    const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textMuted),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              ChoflyButton(
                label: 'Créer le code',
                isLoading: _isCreating,
                onPressed: _isCreating ? null : _create,
                icon: Icons.add_rounded,
              ),
            ]),
          ),

          const SizedBox(height: 20),
          const SectionHeader(title: 'Codes actifs'),
          const SizedBox(height: 12),

          // ── List ─────────────────────────────────────────
          StreamBuilder<List<PromoCode>>(
            stream: _promoService.watchAllPromos(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Column(children: [SkeletonCard(), SkeletonCard()]);
              }
              final promos = snap.data ?? [];
              if (promos.isEmpty) {
                return const EmptyState(
                    emoji: '🎟️', title: 'Aucun code', subtitle: 'Créez votre premier code promo');
              }
              return Column(
                children: promos.map((p) => _PromoTile(promo: p, service: _promoService)).toList(),
              );
            },
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StepBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppTheme.card2, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(child: Text(label, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  final PromoCode promo;
  final PromoService service;
  const _PromoTile({required this.promo, required this.service});

  @override
  Widget build(BuildContext context) {
    final isValid = promo.isValid;
    final usageRatio = promo.usageLimit > 0
        ? promo.usageCount / promo.usageLimit : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isValid ? AppTheme.border : AppTheme.redBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Row(children: [
            Text(promo.code, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: AppTheme.green, letterSpacing: 1)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: promo.discountPercent > 0 ? Color.fromRGBO(46, 204, 113, 0.12) : Color.fromRGBO(255, 209, 102, 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                promo.discountPercent > 0
                    ? '-${promo.discountPercent}%'
                    : '-${promo.discountFixed} DA',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: promo.discountPercent > 0 ? AppTheme.green : AppTheme.yellow,
                ),
              ),
            ),
          ])),
          // Toggle active
          GestureDetector(
            onTap: () => service.togglePromo(promo.id, !promo.isActive),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: promo.isActive ? AppTheme.greenDim : AppTheme.redDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(promo.isActive ? 'Actif' : 'Inactif', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: promo.isActive ? AppTheme.green : AppTheme.red,
              )),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(promo.description,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        // Usage bar
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${promo.usageCount} / ${promo.usageLimit} utilisations',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          Text('Expire ${promo.expiresAt.day}/${promo.expiresAt.month}/${promo.expiresAt.year}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: usageRatio.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(
              usageRatio > 0.8 ? AppTheme.red : AppTheme.green),
          ),
        ),
      ]),
    );
  }
}
