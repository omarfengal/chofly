// lib/screens/customer/request_tracking_screen.dart
// TÂCHE 1 — Tracking immersif: carte 50% écran par défaut,
//            ETA dynamique, animation prestataire, barre progression

import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_service.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_extensions.dart';
import '../chat/chat_screen.dart';
import 'rating_screen.dart';

class RequestTrackingScreen extends StatelessWidget {
  final String requestId;
  const RequestTrackingScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ServiceRequest?>(
      stream: RequestService().getRequest(requestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            body: Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.green))),
          );
        }
        return _TrackingView(request: snapshot.data!);
      },
    );
  }
}

class _TrackingView extends StatefulWidget {
  final ServiceRequest request;
  const _TrackingView({required this.request});
  @override
  State<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<_TrackingView> with TickerProviderStateMixin {
  GoogleMapController? _mapController;

  // TÂCHE 1a: carte visible par défaut à 50% de l'écran
  static const double _mapCollapsedFraction = 0.5;
  bool _mapExpanded = false;

  // TÂCHE 1b: countdown 2h SLA
  late Duration _remaining;
  Timer? _countdownTimer;

  // TÂCHE 1c: marqueur animé du prestataire
  LatLng? _providerPosition;
  AnimationController? _markerPulseCtrl;
  Animation<double>? _markerPulse;

  // TÂCHE 1d: ETA calculé depuis la position du prestataire
  int? _etaMinutes;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _setupMarkerAnimation();
    _listenProviderLocation();
  }

  void _startCountdown() {
    const sla = Duration(hours: 2);
    final deadline = widget.request.createdAt.add(sla);
    _remaining = deadline.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = deadline.difference(DateTime.now());
      setState(() => _remaining = r.isNegative ? Duration.zero : r);
    });
  }

  void _setupMarkerAnimation() {
    _markerPulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _markerPulse = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _markerPulseCtrl!, curve: Curves.easeInOut));
  }

  // TÂCHE 1c: écouter la position du prestataire en temps réel
  void _listenProviderLocation() {
    if (widget.request.providerId == null) return;
    ProviderService().watchProvider(widget.request.providerId!).listen((provider) {
      if (!mounted || provider?.lastLocation == null) return;
      final newPos = LatLng(
        provider!.lastLocation!.latitude,
        provider.lastLocation!.longitude,
      );
      setState(() {
        _providerPosition = newPos;
        // TÂCHE 1d: calcul ETA haversine depuis position prestataire → domicile
        if (widget.request.location != null) {
          _etaMinutes = _calculateETA(
            from: newPos,
            to: LatLng(widget.request.location!.latitude,
                       widget.request.location!.longitude),
          );
        }
      });
      // Animer la caméra vers la nouvelle position
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));
    });
  }

  // TÂCHE 1d: ETA via formule haversine (vitesse moyenne 30 km/h urbain)
  int _calculateETA({required LatLng from, required LatLng to}) {
    const R = 6371.0; // rayon Terre km
    final dLat = _deg2rad(to.latitude - from.latitude);
    final dLon = _deg2rad(to.longitude - from.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(from.latitude)) * cos(_deg2rad(to.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distKm = R * c;
    const avgSpeedKmh = 30.0; // vitesse urbaine Algérie
    return ((distKm / avgSpeedKmh) * 60).ceil().clamp(1, 120);
  }

  double _deg2rad(double deg) => deg * pi / 180;

  String get _myId => context.read<AuthProvider>().firebaseUser?.uid ?? '';

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _markerPulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final isActive = [RequestStatus.pending, RequestStatus.accepted,
        RequestStatus.inProgress].contains(widget.request.status);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: ChoflyAppBar(
        title: 'Suivi de demande',
        actions: [
          if (widget.request.providerId != null)
            _ChatButton(requestId: widget.request.id, myId: _myId,
                providerName: widget.request.providerName ?? 'Technicien'),
          StatusBadge(status: widget.request.status),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // ── TÂCHE 1a: carte 50% écran par défaut ──────────────
          if (isActive) AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            height: _mapExpanded
                ? screenH * 0.7
                : screenH * _mapCollapsedFraction,
            child: _ImmersiveMap(
              request: widget.request,
              providerPosition: _providerPosition,
              expanded: _mapExpanded,
              markerPulse: _markerPulse,
              onToggle: () => setState(() => _mapExpanded = !_mapExpanded),
              onMapCreated: (c) => _mapController = c,
            ),
          ),

          // ── ETA banner flottant (TÂCHE 1d) ───────────────────
          if (isActive && _etaMinutes != null)
            _ETABanner(etaMinutes: _etaMinutes!),

          // ── Contenu scrollable ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _StatusCard(request: widget.request),
                const SizedBox(height: 12),
                if (isActive)
                  _CountdownBanner(remaining: _remaining),
                const SizedBox(height: 12),
                RequestTimeline(currentStatus: widget.request.status),
                const SizedBox(height: 12),
                if (widget.request.providerId != null) ...[
                  _ProviderCard(request: widget.request, myId: _myId),
                  const SizedBox(height: 12),
                ],
                _DetailsCard(request: widget.request),
                const SizedBox(height: 12),
                _PriceCard(request: widget.request),
                const SizedBox(height: 20),
                _Actions(request: widget.request),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TÂCHE 1: Carte immersive avec marqueur animé ──────────────
class _ImmersiveMap extends StatelessWidget {
  final ServiceRequest request;
  final LatLng? providerPosition;
  final bool expanded;
  final Animation<double>? markerPulse;
  final VoidCallback onToggle;
  final Function(GoogleMapController) onMapCreated;

  const _ImmersiveMap({
    required this.request, required this.providerPosition,
    required this.expanded, this.markerPulse,
    required this.onToggle, required this.onMapCreated,
  });

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    // Marqueur domicile client
    if (request.location != null) {
      markers.add(Marker(
        markerId: const MarkerId('home'),
        position: LatLng(request.location!.latitude, request.location!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: '🏠 Votre domicile'),
      ));
    }
    // Marqueur prestataire (position temps réel)
    if (providerPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('provider'),
        position: providerPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '🔧 Votre technicien'),
        rotation: 0,
      ));
    }
    return markers;
  }

  Set<Polyline> _buildRoute() {
    if (providerPosition == null || request.location == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          providerPosition!,
          LatLng(request.location!.latitude, request.location!.longitude),
        ],
        color: AppTheme.green.withOpacity(0.7),
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final loc = request.location;
    final center = providerPosition ??
        (loc != null ? LatLng(loc.latitude, loc.longitude) : const LatLng(36.75, 3.06));

    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: onMapCreated,
            initialCameraPosition: CameraPosition(target: center, zoom: 14),
            markers: _buildMarkers(),
            polylines: _buildRoute(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
          ),
          // Overlay gradient bas de carte
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.bg.withOpacity(0.9)],
                ),
              ),
            ),
          ),
          // Bouton expand/collapse
          Positioned(
            bottom: 10, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.bg.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(expanded ? Icons.compress_rounded : Icons.expand_rounded,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(expanded ? 'Réduire' : 'Agrandir',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
          ),
          // Indicateur "en route" si prestataire localisé
          if (providerPosition != null)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Technicien en route', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── TÂCHE 1d: ETA banner ──────────────────────────────────────
class _ETABanner extends StatelessWidget {
  final int etaMinutes;
  const _ETABanner({required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.greenDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.greenBorder),
      ),
      child: Row(children: [
        const Icon(Icons.directions_car_rounded, size: 18, color: AppTheme.green),
        const SizedBox(width: 10),
        Text('ETA estimée :',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(width: 6),
        Text('$etaMinutes min',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: AppTheme.green)),
        const Spacer(),
        const Text('(selon position GPS)', style: TextStyle(
            fontSize: 10, color: AppTheme.textMuted)),
      ]),
    );
  }
}

// ── Countdown banner ──────────────────────────────────────────
class _CountdownBanner extends StatelessWidget {
  final Duration remaining;
  const _CountdownBanner({required this.remaining});

  String get _label {
    if (remaining == Duration.zero) return 'Garantie expirée';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2,'0')}min';
    if (m > 0) return '${m}min ${s.toString().padLeft(2,'0')}s';
    return '${s}s';
  }

  Color get _color {
    if (remaining == Duration.zero) return AppTheme.red;
    if (remaining.inMinutes < 15) return AppTheme.red;
    if (remaining.inMinutes < 30) return AppTheme.orange;
    return AppTheme.green;
  }

  @override
  Widget build(BuildContext context) {
    final pct = remaining == Duration.zero ? 1.0
        : 1.0 - (remaining.inSeconds / const Duration(hours: 2).inSeconds);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.timer_outlined, size: 16, color: _color),
          const SizedBox(width: 8),
          const Text('Garantie intervention 2h',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const Spacer(),
          Text(_label, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w800, color: _color)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0), minHeight: 5,
            backgroundColor: AppTheme.card2,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ]),
    );
  }
}

// ── Chat badge button ─────────────────────────────────────────
class _ChatButton extends StatelessWidget {
  final String requestId, myId, providerName;
  const _ChatButton({required this.requestId, required this.myId, required this.providerName});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ChatService().unreadCount(requestId, myId),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(requestId: requestId, otherPartyName: providerName))),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppTheme.green),
              if (unread > 0) ...[
                const SizedBox(width: 5),
                Container(
                  width: 17, height: 17,
                  decoration: const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle),
                  child: Center(child: Text('$unread', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

// ── Status card ───────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final ServiceRequest request;
  const _StatusCard({required this.request});
  String get _emoji => switch (request.status) {
    RequestStatus.pending => '⏳', RequestStatus.accepted => '🚗',
    RequestStatus.inProgress => '🔧', RequestStatus.completed => '✅',
    RequestStatus.cancelled => '❌', RequestStatus.rejected => '😞',
  };
  String get _title => switch (request.status) {
    RequestStatus.pending => "En attente d'un technicien",
    RequestStatus.accepted => 'Technicien en route !',
    RequestStatus.inProgress => 'Intervention en cours',
    RequestStatus.completed => 'Service terminé',
    RequestStatus.cancelled => 'Demande annulée',
    RequestStatus.rejected => 'Demande refusée',
  };
  String get _sub => switch (request.status) {
    RequestStatus.pending => 'Nous cherchons le meilleur technicien disponible…',
    RequestStatus.accepted => 'Votre technicien arrive dans moins de 2h garantie',
    RequestStatus.inProgress => 'Le technicien travaille sur votre problème',
    RequestStatus.completed => 'Mission accomplie ! Merci de votre confiance.',
    RequestStatus.cancelled => 'Votre demande a été annulée',
    RequestStatus.rejected => 'Nous allons trouver un autre technicien',
  };
  @override
  Widget build(BuildContext context) {
    final isActive = [RequestStatus.pending, RequestStatus.accepted,
        RequestStatus.inProgress].contains(request.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.greenDim : AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? AppTheme.greenBorder : AppTheme.border),
      ),
      child: Row(children: [
        Text(_emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 3),
          Text(_sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
        ])),
      ]),
    );
  }
}

// ── Provider card ─────────────────────────────────────────────
class _ProviderCard extends StatelessWidget {
  final ServiceRequest request;
  final String myId;
  const _ProviderCard({required this.request, required this.myId});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProviderModel?>(
      stream: ProviderService().watchProvider(request.providerId!),
      builder: (context, snap) {
        final p = snap.data;
        final name = p?.name ?? request.providerName ?? '?';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: AppTheme.card2,
              child: Text(name[0].toUpperCase(), style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.green))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              if (p != null) Row(children: [
                const Icon(Icons.star_rounded, size: 12, color: AppTheme.yellow),
                const SizedBox(width: 3),
                Text(p.averageRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                if (p.isVerified) const VerifiedBadge(),
              ]),
            ])),
            _IconBtn(icon: Icons.phone_rounded, color: AppTheme.green, bgColor: AppTheme.greenDim,
                onTap: () async {
                  final uri = Uri.parse('tel:${p?.phone ?? ''}');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                }),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.chat_bubble_outline_rounded, color: AppTheme.textSecondary, bgColor: AppTheme.card2,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(requestId: request.id, otherPartyName: name)))),
          ]),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color, bgColor; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.bgColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border)),
      child: Icon(icon, size: 16, color: color)),
  );
}

class _DetailsCard extends StatelessWidget {
  final ServiceRequest request;
  const _DetailsCard({required this.request});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Détails', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        _Row('Service', request.categoryLabel),
        _Row('Problème', request.issueType),
        if (request.description.isNotEmpty) _Row('Note', request.description),
        _Row('Adresse', request.address),
        _Row('Créée', request.createdAt.timeAgo),
        if (request.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(height: 68, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: request.photoUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: request.photoUrls[i], width: 68, height: 68, fit: BoxFit.cover),
            ),
          )),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _PriceCard extends StatelessWidget {
  final ServiceRequest request;
  const _PriceCard({required this.request});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppTheme.card,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('💵 Paiement espèces', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        Text('Après intervention', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ]),
      Text(
        request.finalPrice != null
            ? '${request.finalPrice} DA'
            : '${request.priceRangeMin}–${request.priceRangeMax} DA',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.green),
      ),
    ]),
  );
}

class _Actions extends StatefulWidget {
  final ServiceRequest request;
  const _Actions({required this.request});
  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _generatingPdf = false;
  Future<void> _downloadReceipt() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await ReceiptService.generatePDF(widget.request);
      await Printing.sharePdf(bytes: bytes,
          filename: 'recu_chofly_${widget.request.id.substring(0, 8)}.pdf');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur PDF'), backgroundColor: AppTheme.red));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.request.status == RequestStatus.completed && !widget.request.isRated)
        ChoflyButton(
          label: '⭐ Évaluer le technicien',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RatingScreen(request: widget.request))),
        ),
      if (widget.request.status == RequestStatus.completed) ...[
        const SizedBox(height: 10),
        ChoflyButton(
          label: '📄 Télécharger le reçu',
          isOutlined: true, isLoading: _generatingPdf,
          onPressed: _generatingPdf ? null : _downloadReceipt,
        ),
      ],
      if (widget.request.status == RequestStatus.pending) ...[
        const SizedBox(height: 10),
        ChoflyButton(
          label: 'Annuler la demande', color: AppTheme.red,
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppTheme.card,
                title: const Text('Annuler ?', style: TextStyle(color: AppTheme.textPrimary)),
                content: const Text('Cette action est irréversible.', style: TextStyle(color: AppTheme.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Non', style: TextStyle(color: AppTheme.textSecondary))),
                  TextButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('Oui', style: TextStyle(color: AppTheme.red))),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              await context.read<RequestProvider>().cancelRequest(widget.request.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
        ),
      ],
    ]);
  }
}
