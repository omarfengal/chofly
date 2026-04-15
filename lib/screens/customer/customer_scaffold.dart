import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import 'customer_home_screen.dart';
import 'customer_orders_screen.dart';

class CustomerScaffold extends StatefulWidget {
  const CustomerScaffold({super.key});

  @override
  State<CustomerScaffold> createState() => _CustomerScaffoldState();
}

class _CustomerScaffoldState extends State<CustomerScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CustomerHomeScreen(),
    CustomerOrdersScreen(),
    CustomerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // thème-aware
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 0
        ? FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).pushNamed('/customer/new-request'),
            backgroundColor: AppTheme.green,
            foregroundColor: AppTheme.bg,
            elevation: 0,
            icon: const Icon(Icons.add, size: 22),
            label: const Text('Nouvelle demande', style: TextStyle(fontWeight: FontWeight.w700)),
          )
        : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5), // BUG10 FIX: withOpacity for broader Flutter compat
          )),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final uid = auth.firebaseUser?.uid ?? '';
                return StreamBuilder<List<ServiceRequest>>(
                  stream: uid.isNotEmpty
                    ? RequestService().getActiveCustomerRequests(uid)
                    : const Stream.empty(),
                  builder: (context, snap) {
                    final activeCount = snap.data?.length ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                          label: 'Accueil', index: 0, current: _currentIndex,
                          onTap: (i) => setState(() => _currentIndex = i)),
                        // Amélioration 4: badge sur demandes actives
                        _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded,
                          label: 'Demandes', index: 1, current: _currentIndex,
                          badge: activeCount > 0 ? activeCount : null,
                          onTap: (i) => setState(() => _currentIndex = i)),
                        _NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded,
                          label: 'Profil', index: 2, current: _currentIndex,
                          onTap: (i) => setState(() => _currentIndex = i)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;
  final int? badge; // Amélioration 4: badge count

  const _NavItem({required this.icon, required this.activeIcon,
    required this.label, required this.index,
    required this.current, required this.onTap, this.badge});

  bool get isActive => index == current;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.greenDim : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(isActive ? activeIcon : icon,
              color: isActive ? AppTheme.green : AppTheme.textMuted, size: 24),
            if (badge != null && badge! > 0)
              Positioned(
                right: -6, top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? AppTheme.green : AppTheme.textMuted,
          )),
        ]),
      ),
    );
  }
}
