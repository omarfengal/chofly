import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../utils/app_extensions.dart';

// ════════════════════════════════════════════════════════════════
// SKELETON LOADER — theme-aware shimmer
// ════════════════════════════════════════════════════════════════
class SkeletonBox extends StatefulWidget {
  final double width, height, radius;
  const SkeletonBox({super.key, this.width=double.infinity, this.height=16, this.radius=8});
  @override State<SkeletonBox> createState() => _SkeletonBoxState();
}
class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _a = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: isDark
                ? [Color.lerp(AppTheme.card, AppTheme.card2, _a.value)!, Color.lerp(AppTheme.card2, AppTheme.border, _a.value)!]
                : [Color.lerp(AppTheme.borderLight, AppTheme.border2Light, _a.value)!, Color.lerp(AppTheme.bg2Light, AppTheme.borderLight, _a.value)!],
          ),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.card : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.border : AppTheme.borderLight),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SkeletonBox(width: 44, height: 44, radius: 12),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(height: 14), SizedBox(height: 6), SkeletonBox(width: 110, height: 11),
          ])),
          SizedBox(width: 12),
          SkeletonBox(width: 64, height: 26, radius: 8),
        ]),
        SizedBox(height: 12),
        SkeletonBox(height: 10), SizedBox(height: 5), SkeletonBox(width: 160, height: 10),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STAR RATING
// ════════════════════════════════════════════════════════════════
class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;
  const StarRating({super.key, required this.rating, this.onChanged, this.size=38});
  @override Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: onChanged != null ? () { HapticFeedback.selectionClick(); onChanged!(i+1); } : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? AppTheme.yellow : AppTheme.border2,
            ),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TRUST BAR — gradient chips
// ════════════════════════════════════════════════════════════════
class TrustBar extends StatelessWidget {
  const TrustBar({super.key});
  @override Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: const [
          _TrustChip(icon: Icons.verified_rounded,    label: 'Artisans vérifiés'),
          SizedBox(width: 8),
          _TrustChip(icon: Icons.bolt_rounded,        label: 'Intervention < 2h'),
          SizedBox(width: 8),
          _TrustChip(icon: Icons.payments_rounded,    label: 'Cash après service'),
          SizedBox(width: 8),
          _TrustChip(icon: Icons.shield_rounded,      label: 'Satisfait ou refait'),
          SizedBox(width: 8),
          _TrustChip(icon: Icons.workspace_premium_rounded, label: '+500 missions'),
          SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1A2DD36F), Color(0x0A1A8C4A)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTheme.greenBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppTheme.green),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.green, letterSpacing: 0.1,
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// VERIFIED BADGE
// ════════════════════════════════════════════════════════════════
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x1A2DD36F), Color(0x082DD36F)]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.greenBorder),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded, size: 11, color: AppTheme.green),
        SizedBox(width: 4),
        Text('CHOFLY Vérifié', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.green, letterSpacing: 0.3,
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PULSING DOT — pour les statuts actifs/live
// ════════════════════════════════════════════════════════════════
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingDot({super.key, this.color=AppTheme.green, this.size=10});
  @override State<PulsingDot> createState() => _PulsingDotState();
}
class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        Container(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.15 * _a.value),
          ),
        ),
        Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// REQUEST TIMELINE — polished with glow on active step
// ════════════════════════════════════════════════════════════════
class RequestTimeline extends StatelessWidget {
  final RequestStatus currentStatus;
  const RequestTimeline({super.key, required this.currentStatus});

  static const _steps = [RequestStatus.pending, RequestStatus.accepted, RequestStatus.inProgress, RequestStatus.completed];
  static const _labels = ['Demandé', 'Accepté', 'En cours', 'Terminé'];
  static const _icons  = [Icons.send_rounded, Icons.check_rounded, Icons.build_rounded, Icons.celebration_rounded];

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCancelled = currentStatus == RequestStatus.cancelled || currentStatus == RequestStatus.rejected;
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.redDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.redBorder),
        ),
        child: const Row(children: [
          Icon(Icons.cancel_rounded, color: AppTheme.red, size: 20),
          SizedBox(width: 10),
          Text('Demande annulée', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    final idx = _steps.indexOf(currentStatus);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.card : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.border : AppTheme.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Progression', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          const Spacer(),
          if (currentStatus == RequestStatus.inProgress) ...[
            PulsingDot(size: 7), const SizedBox(width: 5),
            const Text('En direct', style: TextStyle(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600)),
          ],
        ]),
        const SizedBox(height: 18),
        Row(children: List.generate(_steps.length, (i) {
          final done = idx >= i;
          final current = idx == i;
          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: current ? 38 : 30, height: current ? 38 : 30,
                decoration: BoxDecoration(
                  gradient: done ? AppTheme.greenGradient : null,
                  color: done ? null : (isDark ? AppTheme.card2 : AppTheme.bg2Light),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? AppTheme.green : (isDark ? AppTheme.border2 : AppTheme.border2Light),
                    width: current ? 2.5 : 1.5,
                  ),
                  boxShadow: current ? AppTheme.greenGlowShadow : null,
                ),
                child: Icon(_icons[i], size: current ? 18 : 14, color: done ? Colors.white : AppTheme.textMuted),
              ),
              const SizedBox(height: 7),
              Text(_labels[i], style: TextStyle(
                fontSize: 9, fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                color: done ? AppTheme.green : AppTheme.textMuted, letterSpacing: 0.2,
              )),
            ])),
            if (i < _steps.length - 1)
              Expanded(child: Container(
                height: 2, margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  gradient: idx > i ? AppTheme.greenGradientH : null,
                  color: idx > i ? null : (isDark ? AppTheme.border2 : AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(1),
                ),
              )),
          ]));
        })),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// REQUEST CARD — with left accent strip + gradient
// ════════════════════════════════════════════════════════════════
class RequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onTap;
  const RequestCard({super.key, required this.request, required this.onTap});

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = request.status.color;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.card : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.border : AppTheme.borderLight),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(children: [
              // Left accent strip
              Container(
                width: 3.5,
                height: double.infinity,
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [accentColor, accentColor.withOpacity(0.3)],
                  ),
                ),
              ),
              // Content
              Expanded(child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(children: [
                  // Icon bubble
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.card2 : AppTheme.bg2Light,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppTheme.border2 : AppTheme.borderLight),
                    ),
                    child: Center(child: Text(
                      ServiceData.categories[request.category]?['icon'] as String? ?? '🔧',
                      style: const TextStyle(fontSize: 22),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(request.categoryLabel, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                    )),
                    const SizedBox(height: 2),
                    Text(request.issueType, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.access_time_rounded, size: 10, color: AppTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(request.createdAt.timeAgo, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ]),
                  ])),
                  _StatusPill(status: request.status),
                ]),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final RequestStatus status;
  const _StatusPill({required this.status});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: status.color)),
        const SizedBox(width: 4),
        Text(status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status.color)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATUS BADGE
// ════════════════════════════════════════════════════════════════
class StatusBadge extends StatelessWidget {
  final RequestStatus status;
  const StatusBadge({super.key, required this.status});
  @override Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: status.color)),
        const SizedBox(width: 5),
        Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RATING WIDGET
// ════════════════════════════════════════════════════════════════
class RatingWidget extends StatelessWidget {
  final double rating;
  final int reviewCount;
  const RatingWidget({super.key, required this.rating, required this.reviewCount});
  @override Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: AppTheme.yellow, size: 14),
      const SizedBox(width: 3),
      Text('${rating.toStringAsFixed(1)}', style: const TextStyle(
        fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w700,
      )),
      const SizedBox(width: 2),
      Text('($reviewCount)', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// SECTION HEADER
// ════════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 3, height: 18,
          decoration: BoxDecoration(
            gradient: AppTheme.greenGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(title, style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
          letterSpacing: -0.2,
        )),
      ]),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: const TextStyle(
            fontSize: 13, color: AppTheme.green, fontWeight: FontWeight.w600,
          )),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// EMPTY STATE — geometric decoration
// ════════════════════════════════════════════════════════════════
class EmptyState extends StatelessWidget {
  final String emoji, title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.emoji, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 96, height: 96,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0x202DD36F), Color(0x00000000)]),
                border: Border.all(color: AppTheme.greenBorder),
              ),
            ),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.greenDim,
                border: Border.all(color: AppTheme.greenBorder),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 14, color: AppTheme.textSecondary, height: 1.6,
        )),
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppTheme.greenBorder),
              color: AppTheme.greenDim,
            ),
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
              child: Text(actionLabel!, style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// INFO TILE — theme-aware
// ════════════════════════════════════════════════════════════════
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const InfoTile({super.key, required this.icon, required this.label, required this.value});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: AppTheme.greenDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.greenBorder),
          ),
          child: Icon(icon, size: 16, color: AppTheme.green),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
          )),
        ])),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CHOFLY BUTTON — gradient + glow primary
// ════════════════════════════════════════════════════════════════
class ChoflyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading, isOutlined;
  final IconData? icon;
  final Color? color;
  final double height;
  const ChoflyButton({
    super.key, required this.label, this.onPressed, this.isLoading=false,
    this.isOutlined=false, this.icon, this.color, this.height=56,
  });
  @override State<ChoflyButton> createState() => _ChoflyButtonState();
}
class _ChoflyButtonState extends State<ChoflyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _s;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 80), lowerBound: 0.97, upperBound: 1.0, value: 1.0);
    _s = _c;
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  void _down(_) { if (widget.onPressed != null && !widget.isLoading) _c.reverse(); }
  void _up(_)  => _c.forward();

  @override Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.color ?? AppTheme.green;
    final isPrimary = !widget.isOutlined;
    return GestureDetector(
      onTapDown: _down, onTapUp: _up, onTapCancel: () => _c.forward(),
      onTap: () {
        if (widget.isLoading || widget.onPressed == null) return;
        HapticFeedback.lightImpact();
        widget.onPressed!();
      },
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: double.infinity, height: widget.height,
          decoration: BoxDecoration(
            gradient: isPrimary && widget.color == null ? AppTheme.greenGradient : null,
            color: isPrimary && widget.color != null ? primary : (widget.isOutlined ? Colors.transparent : primary),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: widget.isOutlined ? Border.all(color: widget.color ?? AppTheme.border2, width: 1.5) : null,
            boxShadow: isPrimary && widget.onPressed != null ? AppTheme.greenGlowShadow : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isOutlined ? primary : (isDark ? AppTheme.bg : Colors.white),
                    ),
                  ))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: widget.isOutlined ? primary : (isDark ? AppTheme.bg : Colors.white)),
                      const SizedBox(width: 8),
                    ],
                    Text(widget.label, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1,
                      color: widget.isOutlined ? primary : (isDark ? AppTheme.bg : Colors.white),
                    )),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CHOFLY APP BAR
// ════════════════════════════════════════════════════════════════
class ChoflyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget>? actions;
  const ChoflyAppBar({super.key, required this.title, this.subtitle, this.showBack=true, this.actions});
  @override Size get preferredSize => Size.fromHeight(subtitle != null ? 66 : 56);
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0, scrolledUnderElevation: 0,
      title: subtitle != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight)),
              Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ])
          : Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight, letterSpacing: -0.3)),
      leading: showBack
          ? IconButton(
              onPressed: () { HapticFeedback.selectionClick(); Navigator.of(context).pop(); },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            )
          : null,
      automaticallyImplyLeading: false,
      actions: actions,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CHOFLY LOADER — animated ring
// ════════════════════════════════════════════════════════════════
class ChoflyLoader extends StatefulWidget {
  const ChoflyLoader({super.key});
  @override State<ChoflyLoader> createState() => _ChoflyLoaderState();
}
class _ChoflyLoaderState extends State<ChoflyLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.rotate(
          angle: _c.value * 2 * math.pi,
          child: Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [AppTheme.green, AppTheme.greenDim, Colors.transparent]),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.bg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ERROR BANNER
// ════════════════════════════════════════════════════════════════
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBanner({super.key, required this.message, this.onRetry});
  @override Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.redDim, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.redBorder),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: AppTheme.red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.red))),
        if (onRetry != null)
          GestureDetector(
            onTap: onRetry,
            child: const Text('Réessayer', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CATEGORY CARD — gradient icon sphere
// ════════════════════════════════════════════════════════════════
class CategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final bool isSelected;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.isSelected, required this.onTap});

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = ServiceData.categories[category]!;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2E1A), Color(0xFF111811)])
              : null,
          color: isSelected ? null : (isDark ? AppTheme.card : AppTheme.cardLight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.green : (isDark ? AppTheme.border : AppTheme.borderLight),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? AppTheme.greenGlowShadow : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.greenGradient : null,
              color: isSelected ? null : (isDark ? AppTheme.card2 : AppTheme.bg2Light),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? AppTheme.green : (isDark ? AppTheme.border2 : AppTheme.borderLight)),
            ),
            child: Center(child: Text(data['icon'] as String, style: const TextStyle(fontSize: 22))),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['label'] as String, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isSelected ? AppTheme.green : (isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight),
            )),
            const SizedBox(height: 2),
            Text('dès ${(data['priceMin'] as int).formattedDA}', style: const TextStyle(
              fontSize: 10, color: AppTheme.textMuted,
            )),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NO INTERNET BANNER
// ════════════════════════════════════════════════════════════════
class NoInternetBanner extends StatelessWidget {
  const NoInternetBanner({super.key});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.red, Color(0xFFD44040)]),
      ),
      child: const SafeArea(bottom: false, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
        SizedBox(width: 8),
        Text('Pas de connexion internet', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ])),
    );
  }
}
