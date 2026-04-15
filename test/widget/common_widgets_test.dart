// test/widget/common_widgets_test.dart — Tests de widgets CHOFLY

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chofly/widgets/common_widgets.dart';
import 'package:chofly/utils/app_theme.dart';
import 'package:chofly/models/models.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  // ── ChoflyButton ─────────────────────────────────────────────
  group('ChoflyButton', () {
    testWidgets('affiche le label', (tester) async {
      await tester.pumpWidget(_wrap(
        ChoflyButton(label: 'Continuer', onPressed: () {}),
      ));
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('désactivé si onPressed=null', (tester) async {
      await tester.pumpWidget(_wrap(
        const ChoflyButton(label: 'Désactivé', onPressed: null),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('affiche CircularProgressIndicator si isLoading=true', (tester) async {
      await tester.pumpWidget(_wrap(
        ChoflyButton(label: 'Chargement', onPressed: () {}, isLoading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('onPressed appelé au tap', (tester) async {
      int count = 0;
      await tester.pumpWidget(_wrap(
        ChoflyButton(label: 'Tap', onPressed: () => count++),
      ));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(count, 1);
    });
  });

  // ── SkeletonBox ──────────────────────────────────────────────
  group('SkeletonBox', () {
    testWidgets('se monte sans erreur', (tester) async {
      await tester.pumpWidget(_wrap(const SkeletonBox(width: 200, height: 20)));
      expect(find.byType(SkeletonBox), findsOneWidget);
    });

    testWidgets('SkeletonCard se monte sans erreur', (tester) async {
      await tester.pumpWidget(_wrap(const SkeletonCard()));
      expect(find.byType(SkeletonCard), findsOneWidget);
    });
  });

  // ── StatusBadge ──────────────────────────────────────────────
  group('StatusBadge', () {
    testWidgets('affiche le label du statut', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusBadge(status: RequestStatus.pending),
      ));
      expect(find.text('En attente'), findsOneWidget);
    });

    testWidgets('completed → label Terminé', (tester) async {
      await tester.pumpWidget(_wrap(
        StatusBadge(status: RequestStatus.completed),
      ));
      expect(find.text('Terminé'), findsOneWidget);
    });
  });

  // ── StarRating ───────────────────────────────────────────────
  group('StarRating', () {
    testWidgets('affiche 5 étoiles', (tester) async {
      await tester.pumpWidget(_wrap(
        StarRating(rating: 3, onChanged: (_) {}),
      ));
      // 5 icônes stars
      expect(find.byIcon(Icons.star_rounded), findsWidgets);
    });

    testWidgets('onChanged appelé au tap', (tester) async {
      int? tapped;
      await tester.pumpWidget(_wrap(
        StarRating(rating: 3, size: 40, onChanged: (v) => tapped = v),
      ));
      await tester.tap(find.byIcon(Icons.star_rounded).first);
      await tester.pump();
      expect(tapped, isNotNull);
    });
  });
}
