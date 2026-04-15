import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // BUG7 FIX: import at top
import '../models/models.dart';
import '../utils/app_theme.dart';

// ── String extensions ─────────────────────────────────────────
extension StringX on String {
  String get initials {
    final parts = trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get whatsappNumber {
    final clean = replaceAll(RegExp(r'[\s\-\+]'), '');
    if (clean.startsWith('0')) return '213${clean.substring(1)}';
    if (clean.startsWith('213')) return clean;
    return '213$clean';
  }

  bool get isValidAlgerianPhone {
    final clean = replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^(05|06|07)[0-9]{8}$').hasMatch(clean) ||
           RegExp(r'^(\+213|0213)[567][0-9]{8}$').hasMatch(clean);
  }
}

// ── DateTime extensions ───────────────────────────────────────
// Remplace le package timeago (supprimé) — zéro dépendance
extension DateTimeX on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60)  return 'À l\'instant';
    if (diff.inMinutes < 60)  return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)    return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1)     return 'Hier';
    if (diff.inDays < 7)      return 'Il y a ${diff.inDays} jours';
    return DateFormat('dd/MM/yyyy').format(this);
  }

  String get formattedDate  => DateFormat('dd/MM/yyyy à HH:mm').format(this);
  String get formattedTime  => DateFormat('HH:mm').format(this);
  String get formattedDay   => DateFormat('EEEE dd MMMM', 'fr').format(this);
}

// ── int extensions ────────────────────────────────────────────
extension IntX on int {
  String get formattedDA {
    final f = NumberFormat('#,###', 'fr');
    return '${f.format(this)} DA';
  }
}

// ── RequestStatus extensions — avec bgColor pre-calculée ──────
extension RequestStatusX on RequestStatus {
  Color get color {
    switch (this) {
      case RequestStatus.pending:    return const Color(0xFFFFB347);
      case RequestStatus.accepted:   return AppTheme.green;
      case RequestStatus.inProgress: return AppTheme.blue;
      case RequestStatus.completed:  return AppTheme.green;
      case RequestStatus.cancelled:  return AppTheme.red;
      case RequestStatus.rejected:   return AppTheme.red;
    }
  }

  // bgColor const — évite withOpacity() à chaque build
  Color get bgColor {
    switch (this) {
      case RequestStatus.pending:    return const Color(0x1AFFB347);
      case RequestStatus.accepted:   return AppTheme.greenDim;
      case RequestStatus.inProgress: return const Color(0x1A74B9FF);
      case RequestStatus.completed:  return AppTheme.greenDim;
      case RequestStatus.cancelled:  return AppTheme.redDim;
      case RequestStatus.rejected:   return AppTheme.redDim;
    }
  }

  String get label {
    switch (this) {
      case RequestStatus.pending:    return 'En attente';
      case RequestStatus.accepted:   return 'Accepté';
      case RequestStatus.inProgress: return 'En cours';
      case RequestStatus.completed:  return 'Terminé';
      case RequestStatus.cancelled:  return 'Annulé';
      case RequestStatus.rejected:   return 'Refusé';
    }
  }

  IconData get icon {
    switch (this) {
      case RequestStatus.pending:    return Icons.hourglass_empty_rounded;
      case RequestStatus.accepted:   return Icons.directions_car_rounded;
      case RequestStatus.inProgress: return Icons.build_rounded;
      case RequestStatus.completed:  return Icons.check_circle_rounded;
      case RequestStatus.cancelled:  return Icons.cancel_rounded;
      case RequestStatus.rejected:   return Icons.sentiment_dissatisfied_rounded;
    }
  }
}

// ── BuildContext extensions ───────────────────────────────────
extension ContextX on BuildContext {
  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.red : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<bool?> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    Color confirmColor = AppTheme.green,
  }) {
    return showDialog<bool>(
      context: this,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700,
        )),
        content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(this, false),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(this, true),
            child: Text(confirmText, style: TextStyle(
              color: confirmColor, fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }
}

// ── URL launcher utility ──────────────────────────────────────
// BUG7 FIX: Moved from rating_screen.dart; import is at top of file.

Future<void> launchUrlString(
  String url, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: mode);
  }
}
