// lib/screens/provider/provider_onboarding_screen.dart
// TÂCHE 5 — Onboarding artisan sécurisé:
//   - upload CIN (pièce d'identité)
//   - statut "En vérification" → "Vérifié"
//   - validation admin simple

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_extensions.dart';
import '../../widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// PROVIDER SETUP SCREEN V2 — avec upload CIN
// Remplace ProviderSetupScreen pour le flow onboarding
// ════════════════════════════════════════════════════════════════
class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key});
  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingState();
}

class _ProviderOnboardingState extends State<ProviderOnboardingScreen> {
  final _providerService = ProviderService();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  Set<ServiceCategory> _selectedSkills = {};
  File? _cinFront; // recto CIN
  File? _cinBack;  // verso CIN
  bool _isLoading = false;
  int _step = 0;   // 0=compétences, 1=CIN, 2=confirmation

  @override
  void dispose() { _bioController.dispose(); super.dispose(); }

  bool get _canProceedStep0 => _selectedSkills.isNotEmpty;
  bool get _canProceedStep1 => _cinFront != null && _cinBack != null;

  Future<void> _pickImage({required bool isFront}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (picked == null) return;
    setState(() {
      if (isFront) _cinFront = File(picked.path);
      else _cinBack = File(picked.path);
    });
  }

  Future<void> _submit() async {
    if (!_canProceedStep0 || !_canProceedStep1) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final uid = auth.firebaseUser!.uid;

    // Upload CIN recto/verso sur Firebase Storage
    String? cinFrontUrl, cinBackUrl;
    try {
      final frontResult = await StorageService.uploadCIN(uid, _cinFront!, 'front');
      cinFrontUrl = frontResult.isSuccess ? frontResult.data : null;

      final backResult = await StorageService.uploadCIN(uid, _cinBack!, 'back');
      cinBackUrl = backResult.isSuccess ? backResult.data : null;
    } catch (_) {
      if (mounted) context.showSnack('Erreur upload CIN. Réessayez.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    // Créer le profil prestataire avec CIN
    final provider = ProviderModel(
      uid: uid,
      name: auth.userModel!.name,
      phone: auth.firebaseUser!.phoneNumber ?? '',
      skills: _selectedSkills
          .map((e) => ServiceData.categories[e]!['label'] as String).toList(),
      wilaya: auth.userModel!.wilaya ?? '',
      commune: auth.userModel!.commune ?? '',
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      // TÂCHE 5: CIN URLs
      idCardFrontUrl: cinFrontUrl,
      idCardBackUrl: cinBackUrl,
      verificationStatus: VerificationStatus.pending, // en attente admin
      createdAt: DateTime.now(),
    );

    await _providerService.createProvider(provider);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacementNamed('/provider/pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: ChoflyAppBar(title: 'Devenir technicien', showBack: _step > 0),
      body: Column(
        children: [
          // Barre de progression des étapes
          _StepProgress(current: _step, total: 3),

          Expanded(child: IndexedStack(
            index: _step,
            children: [
              _SkillsStep(
                selectedSkills: _selectedSkills,
                bioController: _bioController,
                onSkillToggle: (cat) => setState(() {
                  if (_selectedSkills.contains(cat)) _selectedSkills.remove(cat);
                  else _selectedSkills.add(cat);
                }),
              ),
              _CINStep(
                cinFront: _cinFront,
                cinBack: _cinBack,
                onPickFront: () => _pickImage(isFront: true),
                onPickBack: () => _pickImage(isFront: false),
              ),
              _ConfirmStep(
                skills: _selectedSkills,
                hasCIN: _cinFront != null && _cinBack != null,
              ),
            ],
          )),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              if (_step > 0) ...[
                Expanded(
                  child: ChoflyButton(
                    label: 'Retour', isOutlined: true,
                    onPressed: () => setState(() => _step--),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ChoflyButton(
                  label: _step < 2 ? 'Suivant' : 'Soumettre mon profil',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : () {
                    if (_step == 0 && !_canProceedStep0) {
                      context.showSnack('Sélectionnez au moins une compétence', isError: true);
                      return;
                    }
                    if (_step == 1 && !_canProceedStep1) {
                      context.showSnack('Ajoutez les deux faces de votre CIN', isError: true);
                      return;
                    }
                    if (_step < 2) setState(() => _step++);
                    else _submit();
                  },
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Barre de progression ──────────────────────────────────────
class _StepProgress extends StatelessWidget {
  final int current, total;
  const _StepProgress({required this.current, required this.total});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: List.generate(total, (i) {
        final done = i <= current;
        return Expanded(child: Row(children: [
          Expanded(child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            decoration: BoxDecoration(
              color: done ? AppTheme.green : AppTheme.card2,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          if (i < total - 1) const SizedBox(width: 4),
        ]));
      })),
    );
  }
}

// ── Étape 1: Compétences ──────────────────────────────────────
class _SkillsStep extends StatelessWidget {
  final Set<ServiceCategory> selectedSkills;
  final TextEditingController bioController;
  final Function(ServiceCategory) onSkillToggle;
  const _SkillsStep({required this.selectedSkills, required this.bioController, required this.onSkillToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Vos compétences', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        const Text('Sélectionnez vos domaines d\'intervention',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        ...ServiceCategory.values.map((cat) {
          final data = ServiceData.categories[cat]!;
          final selected = selectedSkills.contains(cat);
          return GestureDetector(
            onTap: () => onSkillToggle(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppTheme.greenDim : AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppTheme.green : AppTheme.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Text(data['icon'] as String, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['label'] as String, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.green : AppTheme.textPrimary)),
                  Text('Dès ${(data['priceMin'] as int)} DA',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ])),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.green : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppTheme.green : AppTheme.border2, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 13, color: AppTheme.bg)
                      : null,
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 16),
        const Text('Bio (optionnel)', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: bioController,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Présentez-vous brièvement…'),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ── Étape 2: Upload CIN ───────────────────────────────────────
class _CINStep extends StatelessWidget {
  final File? cinFront, cinBack;
  final VoidCallback onPickFront, onPickBack;
  const _CINStep({required this.cinFront, required this.cinBack,
      required this.onPickFront, required this.onPickBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Vérification d\'identité', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        const Text('Votre pièce d\'identité est nécessaire pour être vérifié CHOFLY.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 20),

        // Recto
        const Text('Recto de la CIN', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        _CINUploadCard(
          file: cinFront,
          placeholder: '📄 Recto de la carte nationale',
          onPick: onPickFront,
        ),
        const SizedBox(height: 14),

        // Verso
        const Text('Verso de la CIN', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        _CINUploadCard(
          file: cinBack,
          placeholder: '📄 Verso de la carte nationale',
          onPick: onPickBack,
        ),
        const SizedBox(height: 16),

        // Info sécurité
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.green),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Vos documents sont chiffrés et uniquement visibles par l\'équipe CHOFLY '
              'pour la vérification. Ils ne seront jamais partagés.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _CINUploadCard extends StatelessWidget {
  final File? file;
  final String placeholder;
  final VoidCallback onPick;
  const _CINUploadCard({required this.file, required this.placeholder, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 130,
        decoration: BoxDecoration(
          color: file != null ? AppTheme.greenDim : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppTheme.green : AppTheme.border,
            width: file != null ? 1.5 : 1,
            style: file != null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(file!, fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppTheme.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 14, color: AppTheme.bg),
                    ),
                  ),
                ]),
              )
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.upload_file_outlined, size: 32, color: AppTheme.textMuted),
                const SizedBox(height: 8),
                Text(placeholder,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                const Text('Appuyer pour sélectionner',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]),
      ),
    );
  }
}

// ── Étape 3: Confirmation ─────────────────────────────────────
class _ConfirmStep extends StatelessWidget {
  final Set<ServiceCategory> skills;
  final bool hasCIN;
  const _ConfirmStep({required this.skills, required this.hasCIN});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        const Text('⏳', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 16),
        const Text('Profil prêt à soumettre', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Notre équipe vérifiera votre profil sous 24–48h.\n'
          'Vous recevrez une notification SMS dès validation.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
          textAlign: TextAlign.center),
        const SizedBox(height: 28),
        // Résumé
        _SummaryRow(icon: Icons.build_rounded, label: 'Compétences',
            value: '${skills.length} service${skills.length > 1 ? "s" : ""} sélectionné${skills.length > 1 ? "s" : ""}'),
        _SummaryRow(icon: Icons.badge_outlined, label: 'CIN',
            value: hasCIN ? 'Recto + Verso fournis ✓' : 'Non fourni ✗',
            valueColor: hasCIN ? AppTheme.green : AppTheme.red),
        _SummaryRow(icon: Icons.verified_outlined, label: 'Statut initial',
            value: 'En vérification'),
        const SizedBox(height: 20),
        // Checklist vérification CHOFLY
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Processus de vérification CHOFLY',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            ...const [
              '✓ Vérification pièce d\'identité',
              '✓ Contrôle des compétences déclarées',
              '✓ Attribution du badge "CHOFLY Vérifié"',
              '✓ Accès aux missions dès validation',
            ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(t, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color? valueColor;
  const _SummaryRow({required this.icon, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      Icon(icon, size: 16, color: AppTheme.textMuted),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: valueColor ?? AppTheme.textPrimary)),
    ]),
  );
}
