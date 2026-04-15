// lib/utils/connectivity_service.dart
// Service de détection de connectivité — utilise connectivity_plus
// Usage: enrouler le MaterialApp avec ConnectivityWrapper

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_theme.dart';

// ── ConnectivityService (singleton) ──────────────────────────
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void initialize() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });

    // Vérification initiale
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ── ConnectivityWrapper ───────────────────────────────────────
// Wrap autour du Scaffold ou du body pour afficher la bannière offline
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    ConnectivityService.instance.addListener(_onConnectivityChange);
    if (!ConnectivityService.instance.isOnline) _ctrl.forward();
  }

  void _onConnectivityChange() {
    if (!mounted) return;
    if (!ConnectivityService.instance.isOnline) {
      _ctrl.forward();
    } else {
      // Garder la bannière 1s après reconnexion pour confirmer
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _ctrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_onConnectivityChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SlideTransition(
          position: _anim,
          child: ListenableBuilder(
            listenable: ConnectivityService.instance,
            builder: (_, __) {
              final online = ConnectivityService.instance.isOnline;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                color: online ? AppTheme.green : AppTheme.red,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      size: 14,
                      color: AppTheme.bg,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'Connexion rétablie ✓' : 'Pas de connexion internet',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.bg,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
