import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // BUG2 FIX: import moved to top
import '../../services/providers.dart';
import '../../services/firebase_service.dart' show ReferralService;
import 'package:share_plus/share_plus.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// RATING SCREEN
// ════════════════════════════════════════════════════════════════
class RatingScreen extends StatefulWidget {
  final ServiceRequest request;
  const RatingScreen({super.key, required this.request});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    await context.read<RequestProvider>().submitReview(
      requestId: widget.request.id,
      customerId: auth.firebaseUser!.uid,
      customerName: auth.userModel!.name,
      providerId: widget.request.providerId!,
      rating: _rating,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
    );
    if (!mounted) return;
    Navigator.of(context).pop();

    // TÂCHE 3: popup parrainage si 5 étoiles
    if (_rating == 5 && context.mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) _showReferralPopup(context, auth.firebaseUser!.uid);
      });
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Merci pour votre évaluation ! ⭐')));
    }
  }

  // TÂCHE 3: popup parrainage stratégique après 5 étoiles
  void _showReferralPopup(BuildContext context, String uid) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ReferralAfterRatingDialog(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const ChoflyAppBar(title: 'Évaluation'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('🙏', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text('Comment était le service ?', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
            ), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              widget.request.providerName ?? 'Le technicien',
              style: const TextStyle(fontSize: 16, color: AppTheme.green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            StarRating(
              rating: _rating,
              size: 48,
              onChanged: (value) {
                setState(() => _rating = value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              ['', 'Très mauvais 😞', 'Pas bien 😕', 'Bien 🙂', 'Très bien 😊', 'Excellent ! 🤩'][_rating],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Laissez un commentaire (optionnel)...',
              ),
            ),
            const SizedBox(height: 28),
            ChoflyButton(
              label: 'Envoyer l\'évaluation',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : () { HapticFeedback.mediumImpact(); _submit(); }, // Amélioration 5
              icon: Icons.star_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CUSTOMER ORDERS SCREEN (kept here for backward compat only —
// the canonical, tab-based version lives in customer_orders_screen.dart)
// ════════════════════════════════════════════════════════════════
// BUG1 FIX: CustomerProfileScreen duplicate removed from this file.
// BUG7 FIX: launchUrlString moved to app_extensions.dart.
// Both classes now live exclusively in customer_orders_screen.dart.
