import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_extensions.dart';
import '../../config/app_config.dart';

// ════════════════════════════════════════════════════════════════
// PROVIDER SETUP SCREEN
// ════════════════════════════════════════════════════════════════
class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({super.key});

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _providerService = ProviderService();
  final _bioController = TextEditingController();
  Set<ServiceCategory> _selectedSkills = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez au moins une compétence'),
      ));
      return;
    }
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final provider = ProviderModel(
      uid: auth.firebaseUser!.uid,
      name: auth.userModel!.name,
      phone: auth.firebaseUser!.phoneNumber ?? '',
      skills: _selectedSkills.map((e) => e.name).toList(), // BUG9 FIX: store enum name, not label
      wilaya: auth.userModel!.wilaya ?? '',
      commune: auth.userModel!.commune ?? '',
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      createdAt: DateTime.now(),
    );
    await _providerService.createProvider(provider);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacementNamed('/provider/pending');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Profil artisan', showBack: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vos compétences', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
            )),
            const SizedBox(height: 4),
            const Text('Sélectionnez vos domaines d\'intervention', style: TextStyle(
              fontSize: 13, color: AppTheme.textMuted,
            )),
            const SizedBox(height: 14),
            ...ServiceCategory.values.map((cat) {
              final data = ServiceData.categories[cat]!;
              final selected = _selectedSkills.contains(cat);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) _selectedSkills.remove(cat);
                  else _selectedSkills.add(cat);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.greenDim : AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppTheme.green : AppTheme.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(data['icon'] as String, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['label'] as String, style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: selected ? AppTheme.green : AppTheme.textPrimary,
                            )),
                            Text('Dès ${data["priceMin"]} DA / intervention', style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted,
                            )),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.green : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? AppTheme.green : AppTheme.border2,
                            width: 1.5,
                          ),
                        ),
                        child: selected ? const Icon(Icons.check, size: 14, color: AppTheme.bg) : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Bio (optionnel)', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
            )),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Présentez-vous brièvement...',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.yellow),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'Votre profil sera vérifié par notre équipe avant activation (24-48h).',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ChoflyButton(
              label: 'Soumettre mon profil',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PENDING APPROVAL SCREEN
// ════════════════════════════════════════════════════════════════
class ProviderPendingScreen extends StatelessWidget {
  const ProviderPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              const Text('Profil en cours de vérification', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
              ), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Notre équipe vérifie votre profil.\nVous serez notifié par SMS dès validation (24-48h).',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ChoflyButton(
                label: 'Contacter le support',
                isOutlined: true,
                icon: Icons.chat_outlined,
                onPressed: () async {
                  final url = Uri.parse(AppConfig.providerSupportLink);
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                child: const Text('Se déconnecter', style: TextStyle(color: AppTheme.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROVIDER HOME SCREEN
// ════════════════════════════════════════════════════════════════
class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final providerService = ProviderService();
    final requestService = RequestService();

    return StreamBuilder<ProviderModel?>(
      stream: providerService.watchProvider(auth.firebaseUser?.uid ?? ''),
      builder: (context, provSnap) {
        // Check approval
        if (provSnap.hasData && !provSnap.data!.isApproved) {
          return const ProviderPendingScreen();
        }
        final provider = provSnap.data;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppTheme.green,
              // Amélioration 6: pull-to-refresh — Firestore stream se reconnecte auto
              onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bonjour ${provider?.name.split(' ').first ?? ''} 🔧',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: provider?.isOnline == true ? AppTheme.green : AppTheme.textMuted,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      provider?.isOnline == true ? 'Disponible' : 'Hors ligne',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: provider?.isOnline == true ? AppTheme.green : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Online toggle
                            GestureDetector(
                              onTap: () async {
                                final uid = auth.firebaseUser?.uid ?? '';
                                await providerService.toggleOnline(uid, !(provider?.isOnline ?? false));
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 62, height: 34,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: provider?.isOnline == true ? AppTheme.green : AppTheme.card2,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: provider?.isOnline == true ? AppTheme.green : AppTheme.border2,
                                  ),
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  alignment: provider?.isOnline == true ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    width: 24, height: 24,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Stats row
                        Row(
                          children: [
                            Expanded(child: _ProviderStatCard(
                              value: provider?.completedJobs.toString() ?? '0',
                              label: 'Missions',
                              icon: '✅',
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _ProviderStatCard(
                              value: provider?.rating.toStringAsFixed(1) ?? '0.0',
                              label: 'Note',
                              icon: '⭐',
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _ProviderStatCard(
                              value: '${provider?.totalEarnings ?? 0} DA',
                              label: 'Gains',
                              icon: '💰',
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── P1: Nouvelles demandes — filtrées par wilaya ──────────
                if (provider?.isOnline == true) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 8),
                      child: Row(children: [
                        Text('Nouvelles demandes', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                        )),
                        SizedBox(width: 8),
                        _LiveDot(),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: StreamBuilder<List<ServiceRequest>>(
                      stream: requestService.getNewRequests(
                        providerId: auth.firebaseUser?.uid ?? '',
                        skills: provider?.skills ?? [],
                        wilaya: provider?.wilaya ?? '',
                      ),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Column(children: [SkeletonCard(), SkeletonCard()]),
                          );
                        }
                        final newJobs = snap.data ?? [];
                        if (newJobs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: EmptyState(
                              emoji: '🔍',
                              title: 'Aucune nouvelle demande',
                              subtitle: 'Vous serez notifié dès qu'une mission\ncorrespond à vos compétences',
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: newJobs.map((req) => _NewJobCard(
                              request: req,
                              providerId: auth.firebaseUser?.uid ?? '',
                              providerName: provider?.name ?? '',
                            )).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ── Demandes en cours ─────────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
                    child: Text('Demandes en cours', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                    )),
                  ),
                ),

                SliverToBoxAdapter(
                  child: StreamBuilder<List<ServiceRequest>>(
                    stream: requestService.getProviderRequests(auth.firebaseUser?.uid ?? ''),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.green),
                          )),
                        );
                      }
                      final requests = snap.data ?? [];
                      if (requests.isEmpty) {
                        return const EmptyState(
                          emoji: '😴',
                          title: 'Pas de demandes en cours',
                          subtitle: 'Vos missions actives apparaîtront ici',
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: requests.map((req) => _ProviderJobCard(
                            request: req,
                            providerId: auth.firebaseUser?.uid ?? '',
                            providerName: provider?.name ?? '',
                          )).toList(),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

class _ProviderStatCard extends StatelessWidget {
  final String value, label, icon;
  const _ProviderStatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.green,
          )),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _ProviderJobCard extends StatelessWidget {
  final ServiceRequest request;
  final String providerId, providerName;
  const _ProviderJobCard({required this.request, required this.providerId, required this.providerName});

  @override
  Widget build(BuildContext context) {
    final requestService = RequestService();
    final data = ServiceData.categories[request.category]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.greenDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(data['icon'] as String, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.categoryLabel, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                    )),
                    Text(request.issueType, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(children: [
                  const Icon(Icons.person_outline, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(request.customerName, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                  GestureDetector(
                    onTap: () async {
                      final phone = request.customerPhone.replaceAll('+', '');
                      final url = 'https://wa.me/$phone';
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    },
                    child: const Text('📞 Appeler', style: TextStyle(fontSize: 12, color: AppTheme.green, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  // [#3] In-app chat button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/chat', arguments: {
                      'requestId': request.id,
                      'otherPartyName': request.customerName,
                    }),
                    child: const Text('💬 Chat', style: TextStyle(fontSize: 12, color: AppTheme.blue, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${request.address}, ${request.wilaya}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Description
          if (request.description.isNotEmpty)
            Text(request.description, style: const TextStyle(
              fontSize: 13, color: AppTheme.textSecondary, height: 1.4,
            ), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          // Price row
          Row(
            children: [
              const Text('💰', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('${request.priceRangeMin}–${request.priceRangeMax} DA', style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.green,
              )),
              const Spacer(),
              // Action buttons
              ..._actionButtons(context, requestService),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _actionButtons(BuildContext context, RequestService rs) {
    switch (request.status) {
      case RequestStatus.pending:
        return [
          _ActionBtn(label: 'Refuser', color: AppTheme.red, onTap: () => rs.rejectRequest(request.id)),
          const SizedBox(width: 8),
          _ActionBtn(label: 'Accepter', color: AppTheme.green, onTap: () async {
            // P3: Result<void> — affiche erreur si race condition
            final result = await rs.acceptRequest(request.id, providerId, providerName);
            if (result.isFailure && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.errorMessage ?? 'Erreur'),
                backgroundColor: AppTheme.red,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }),
        ];
      case RequestStatus.accepted:
        return [_ActionBtn(label: 'Démarrer', color: AppTheme.blue, onTap: () => rs.startJob(request.id))];
      case RequestStatus.inProgress:
        return [_ActionBtn(label: 'Terminer', color: AppTheme.green, onTap: () => _showCompleteDialog(context, rs))];
      default:
        return [];
    }
  }

  void _showCompleteDialog(BuildContext context, RequestService rs) {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Terminer la mission', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prix final (DA)', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'ex: 3500'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final price = int.tryParse(priceController.text) ?? 0;
              rs.completeJob(request.id, price);
              Navigator.pop(context);
            },
            child: const Text('Confirmer', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Function() onTap; // accepts async callbacks (P3 Result handling)

  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12) // BUG10 FIX,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4) // BUG10 FIX),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: color,
        )),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROVIDER SCAFFOLD
// ════════════════════════════════════════════════════════════════
class ProviderScaffold extends StatefulWidget {
  const ProviderScaffold({super.key});

  @override
  State<ProviderScaffold> createState() => _ProviderScaffoldState();
}

class _ProviderScaffoldState extends State<ProviderScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(
        index: _index,
        children: const [ProviderHomeScreen(), ProviderProfileScreen()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bg3,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProvNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                  label: 'Missions', index: 0, current: _index, onTap: (i) => setState(() => _index = i)),
                _ProvNavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded,
                  label: 'Profil', index: 1, current: _index, onTap: (i) => setState(() => _index = i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProvNavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;

  const _ProvNavItem({required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.greenDim : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: isActive ? AppTheme.green : AppTheme.textMuted, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? AppTheme.green : AppTheme.textMuted,
            )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROVIDER PROFILE SCREEN
// ════════════════════════════════════════════════════════════════
class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final providerService = ProviderService();
    return StreamBuilder<ProviderModel?>(
      stream: providerService.watchProvider(auth.firebaseUser?.uid ?? ''),
      builder: (context, snap) {
        final provider = snap.data;
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: const ChoflyAppBar(title: 'Mon profil', showBack: false),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar + info
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppTheme.card2,
                            child: Text(
                              provider?.name.isNotEmpty == true ? provider!.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.green),
                            ),
                          ),
                          if (provider?.isVerified == true)
                            Positioned(right: 0, bottom: 0,
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.bg2, width: 3),
                                ),
                                child: const Icon(Icons.check, size: 14, color: AppTheme.bg),
                              )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(provider?.name ?? '', style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
                      )),
                      const SizedBox(height: 6),
                      RatingWidget(rating: provider?.rating ?? 0, reviewCount: provider?.completedJobs ?? 0),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Stats
                Row(
                  children: [
                    Expanded(child: _PStatCard(value: provider?.completedJobs.toString() ?? '0', label: 'Missions')),
                    const SizedBox(width: 12),
                    Expanded(child: _PStatCard(value: '${provider?.totalEarnings ?? 0} DA', label: 'Total gains')),
                  ],
                ),
                const SizedBox(height: 24),
                // Skills
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compétences', style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600,
                      )),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: (provider?.skills ?? []).map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.greenDim,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Color.fromRGBO(46, 204, 113, 0.3)),
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 13, color: AppTheme.green, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ChoflyButton(
                  label: 'Se déconnecter',
                  isOutlined: true,
                  color: AppTheme.red,
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PStatCard extends StatelessWidget {
  final String value, label;
  const _PStatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.green)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// P1 — NOUVELLE DEMANDE CARD
// Carte spécifique pour les missions disponibles (pas encore acceptées).
// Affiche Accepter / Ignorer avec feedback Result<void>.
// ════════════════════════════════════════════════════════════════
class _NewJobCard extends StatefulWidget {
  final ServiceRequest request;
  final String providerId, providerName;
  const _NewJobCard({
    required this.request,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<_NewJobCard> createState() => _NewJobCardState();
}

class _NewJobCardState extends State<_NewJobCard> {
  bool _isActing = false;

  Future<void> _accept() async {
    HapticFeedback.heavyImpact(); // Amélioration 5 — action irréversible
    setState(() => _isActing = true);
    final rs = RequestService();
    // P3: Result<void> — on sait si c'est une race condition
    final result = await rs.acceptRequest(
      widget.request.id,
      widget.providerId,
      widget.providerName,
    );
    if (!mounted) return;
    setState(() => _isActing = false);
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.errorMessage ?? 'Erreur'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ServiceData.categories[widget.request.category]!;
    return AnimatedOpacity(
      opacity: _isActing ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.green.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.greenDim, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(data['icon'] as String, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.request.categoryLabel, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                )),
                Text(widget.request.issueType, style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary,
                )),
              ])),
              // Prix estimé
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${widget.request.priceRangeMin}–${widget.request.priceRangeMax} DA',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.green)),
                const Text('estimé', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ]),
            ]),
            const SizedBox(height: 10),
            // Localisation
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '${widget.request.commune.isNotEmpty ? "${widget.request.commune}, " : ""}${widget.request.wilaya}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              )),
              // Temps depuis la demande
              Text(widget.request.createdAt.timeAgo,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ]),
            // Description courte
            if (widget.request.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.request.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
            ],
            const SizedBox(height: 14),
            // Boutons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActing ? null : () {}, // ignorer — disparaît du stream naturellement
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.border2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ignorer', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isActing ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: AppTheme.bg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isActing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                    : const Text('Accepter la mission', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Indicateur "live" animé ────────────────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
      ),
    );
  }
}
