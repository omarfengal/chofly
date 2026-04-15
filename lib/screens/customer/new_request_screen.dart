import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class NewRequestScreen extends StatefulWidget {
  final ServiceCategory? initialCategory;
  const NewRequestScreen({super.key, this.initialCategory});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  int _step = 0;
  ServiceCategory? _category;
  String? _issueType;
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  String? _wilaya;
  String? _commune;
  List<File> _photos = [];

  final _requestService = RequestService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (_category != null) _step = 1;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _wilaya = auth.userModel?.wilaya;
  }

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _catData => _category != null
    ? ServiceData.categories[_category]!
    : ServiceData.categories[ServiceCategory.plumbing]!;

  bool get _canNext {
    switch (_step) {
      case 0: return _category != null;
      case 1: return _issueType != null;
      case 2: return _descController.text.trim().isNotEmpty && _addressController.text.trim().isNotEmpty && _wilaya != null;
      default: return true;
    }
  }

  void _next() {
    if (_step < 3) setState(() => _step++);
    else {
      HapticFeedback.mediumImpact(); // Amélioration 5
      _submit();
    }
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 3) return;
    final picker = ImagePicker();
    // P5: Limite résolution + qualité avant upload — évite envoi de photos 12 MB
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (!mounted) return; // FIX: guard après await
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();

    // BUG11 FIX: Guard against expired session during multi-step form
    if (auth.firebaseUser == null || auth.userModel == null) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session expirée. Veuillez vous reconnecter.'),
          backgroundColor: Colors.red,
        ));
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    final reqProvider = context.read<RequestProvider>();

    List<String> photoUrls = [];
    // P5: Upload avec compression — max 1280px, qualité 80
    if (_photos.isNotEmpty) {
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      for (final photo in _photos) {
        final result = await _requestService.uploadPhoto(photo, tempId);
        if (result.isSuccess) {
          photoUrls.add(result.valueOrNull!);
        }
        // P3: erreur upload ignorée silencieusement — la demande continue sans photo
      }
    }

    final request = ServiceRequest(
      id: '',
      customerId: auth.firebaseUser!.uid,
      customerName: auth.userModel!.name,
      customerPhone: auth.firebaseUser!.phoneNumber ?? '',
      category: _category!,
      issueType: _issueType!,
      description: _descController.text.trim(),
      photoUrls: photoUrls,
      wilaya: _wilaya!,
      commune: _commune ?? '',
      address: _addressController.text.trim(),
      priceRangeMin: _catData['priceMin'] as int,
      priceRangeMax: _catData['priceMax'] as int,
      createdAt: DateTime.now(),
    );

    final submitResult = await reqProvider.submitRequest(request);
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (submitResult.isSuccess) {
      Navigator.of(context).pushReplacementNamed(
        '/customer/request-tracking',
        arguments: submitResult.valueOrNull,
      );
    } else {
      // P3: affiche le vrai message d'erreur (réseau, permission, etc.)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(submitResult.errorMessage ?? 'Erreur lors de l'envoi.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: ChoflyAppBar(
        title: _stepTitle,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text('${_step + 1}/4', style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_step + 1) / 4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(),
            ),
          ),
          // Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ChoflyButton(
              label: _step < 3 ? 'Continuer' : 'Envoyer la demande',
              onPressed: _canNext ? _next : null,
              isLoading: _isSubmitting,
              icon: _step == 3 ? Icons.send_rounded : null,
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Type de service';
      case 1: return 'Problème';
      case 2: return 'Détails';
      case 3: return 'Récapitulatif';
      default: return '';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _Step0(key: const ValueKey(0), selected: _category,
          onSelect: (c) => setState(() => _category = c));
      case 1: return _Step1(key: const ValueKey(1), category: _category!,
          selected: _issueType, onSelect: (i) => setState(() => _issueType = i));
      case 2: return _Step2(
          key: const ValueKey(2),
          descController: _descController,
          addressController: _addressController,
          photos: _photos,
          onPickPhoto: _pickPhoto,
          onRemovePhoto: (i) => setState(() => _photos.removeAt(i)),
          wilaya: _wilaya,
          onWilayaChange: (w) => setState(() => _wilaya = w),
          commune: _commune,
          onCommuneChange: (c) => setState(() => _commune = c),
        );
      case 3: return _Step3(
          key: const ValueKey(3),
          category: _category!,
          issueType: _issueType!,
          description: _descController.text,
          address: _addressController.text,
          wilaya: _wilaya ?? '',
          photos: _photos,
          priceMin: _catData['priceMin'] as int,
          priceMax: _catData['priceMax'] as int,
        );
      default: return const SizedBox.shrink();
    }
  }
}

// ── Step 0: Category ──────────────────────────────────────────
class _Step0 extends StatelessWidget {
  final ServiceCategory? selected;
  final Function(ServiceCategory) onSelect;

  const _Step0({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('De quel service avez-vous besoin ?', style: TextStyle(
            fontSize: 16, color: AppTheme.textSecondary,
          )),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: ServiceCategory.values.map((cat) => CategoryCard(
              category: cat,
              isSelected: selected == cat,
              onTap: () => onSelect(cat),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Issue type ────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final ServiceCategory category;
  final String? selected;
  final Function(String) onSelect;

  const _Step1({super.key, required this.category, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final data = ServiceData.categories[category]!;
    final issues = data['issues'] as List<String>;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quel est le problème ?', style: const TextStyle(
            fontSize: 16, color: AppTheme.textSecondary,
          )),
          const SizedBox(height: 20),
          ...issues.map((issue) => GestureDetector(
            onTap: () => onSelect(issue),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: selected == issue ? AppTheme.greenDim : AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected == issue ? AppTheme.green : AppTheme.border,
                  width: selected == issue ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(issue, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: selected == issue ? AppTheme.green : AppTheme.textPrimary,
                  ))),
                  if (selected == issue)
                    const Icon(Icons.check_circle, color: AppTheme.green, size: 20),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Step 2: Details ───────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final TextEditingController descController;
  final TextEditingController addressController;
  final List<File> photos;
  final VoidCallback onPickPhoto;
  final Function(int) onRemovePhoto;
  final String? wilaya;
  final Function(String?) onWilayaChange;
  final String? commune;
  final Function(String?) onCommuneChange;

  const _Step2({
    super.key,
    required this.descController, required this.addressController,
    required this.photos, required this.onPickPhoto, required this.onRemovePhoto,
    required this.wilaya, required this.onWilayaChange,
    required this.commune, required this.onCommuneChange,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          const Text('Description du problème', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
          )),
          const SizedBox(height: 8),
          TextField(
            controller: descController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Décrivez votre problème en détail...',
            ),
          ),
          const SizedBox(height: 20),
          // Address
          const Text('Adresse d\'intervention', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
          )),
          const SizedBox(height: 8),
          // Wilaya dropdown
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: wilaya,
                isExpanded: true,
                hint: const Text('Wilaya', style: TextStyle(color: AppTheme.textMuted)),
                dropdownColor: AppTheme.card2,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                items: ServiceData.wilayas.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: onWilayaChange,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressController,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Numéro, rue, commune...',
              prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          // Photos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Photos (optionnel)', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary,
              )),
              Text('${photos.length}/3', style: const TextStyle(
                fontSize: 13, color: AppTheme.textMuted,
              )),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...photos.asMap().entries.map((e) => Stack(
                  children: [
                    Container(
                      width: 84, height: 84,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(image: FileImage(e.value), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(top: 4, right: 14, child: GestureDetector(
                      onTap: () => onRemovePhoto(e.key),
                      child: Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: AppTheme.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    )),
                  ],
                )),
                if (photos.length < 3)
                  GestureDetector(
                    onTap: onPickPhoto,
                    child: Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textMuted, size: 24),
                          SizedBox(height: 4),
                          Text('Ajouter', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Summary ───────────────────────────────────────────
class _Step3 extends StatefulWidget {
  final ServiceCategory category;
  final String issueType, description, address, wilaya;
  final List<File> photos;
  final int priceMin, priceMax;
  final Function(PromoCode?) onPromoApplied;

  const _Step3({
    super.key,
    required this.category, required this.issueType,
    required this.description, required this.address,
    required this.wilaya, required this.photos,
    required this.priceMin, required this.priceMax,
    required this.onPromoApplied,
  });
  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
  final _promoCtrl = TextEditingController();
  final _promoService = PromoService();
  PromoCode? _appliedPromo;
  bool _checkingPromo = false;
  String? _promoError;

  @override
  void dispose() { _promoCtrl.dispose(); super.dispose(); }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _checkingPromo = true; _promoError = null; });
    final promo = await _promoService.validateCode(code);
    setState(() { _checkingPromo = false; });
    if (promo != null) {
      setState(() { _appliedPromo = promo; _promoError = null; });
      widget.onPromoApplied(promo);
      HapticFeedback.selectionClick();
    } else {
      setState(() { _appliedPromo = null; _promoError = 'Code invalide ou expiré'; });
      widget.onPromoApplied(null);
    }
  }

  int get _discountedMax {
    if (_appliedPromo == null) return widget.priceMax;
    return widget.priceMax - _appliedPromo!.discountAmount(widget.priceMax);
  }

  @override
  Widget build(BuildContext context) {
    final data = ServiceData.categories[widget.category]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Vérifiez votre demande', style: TextStyle(
          fontSize: 16, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(data['icon'] as String, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['label'] as String, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text(widget.issueType, style: const TextStyle(
                  fontSize: 14, color: AppTheme.textSecondary)),
              ]),
            ]),
            const Divider(color: AppTheme.border, height: 24),
            _SummaryRow(icon: Icons.description_outlined, label: 'Description', value: widget.description),
            const SizedBox(height: 10),
            _SummaryRow(icon: Icons.location_on_outlined, label: 'Adresse',
                value: '${widget.address}, ${widget.wilaya}'),
            if (widget.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SummaryRow(icon: Icons.photo_outlined, label: 'Photos',
                  value: '${widget.photos.length} photo(s) jointe(s)'),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        // [#4] Promo code input
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _appliedPromo != null
                  ? AppTheme.greenBorder
                  : _promoError != null ? AppTheme.redBorder : AppTheme.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.discount_outlined, size: 15, color: AppTheme.green),
              SizedBox(width: 6),
              Text('Code promo', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _promoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'ex: ETE2025',
                    border: InputBorder.none, enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none, filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _checkingPromo ? null : _applyPromo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.green, borderRadius: BorderRadius.circular(10)),
                  child: _checkingPromo
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                    : const Text('Appliquer', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.bg)),
                ),
              ),
            ]),
            if (_promoError != null)
              Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(_promoError!, style: const TextStyle(
                    fontSize: 11, color: AppTheme.red))),
            if (_appliedPromo != null)
              Padding(padding: const EdgeInsets.only(top: 6),
                child: Text('✓ ${_appliedPromo!.description} — '
                    '-${_appliedPromo!.discountPercent > 0 ? "${_appliedPromo!.discountPercent}%" : "${_appliedPromo!.discountFixed} DA"}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.green,
                      fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 14),

        // Price estimate
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.greenDim, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.greenBorder),
          ),
          child: Row(children: [
            const Text('💰', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimation du prix', style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
              if (_appliedPromo != null)
                Text('${widget.priceMin} – ${widget.priceMax} DA',
                  style: const TextStyle(fontSize: 12,
                    color: AppTheme.textMuted,
                    decoration: TextDecoration.lineThrough)),
              Text('${widget.priceMin} – $_discountedMax DA',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppTheme.green)),
            ]),
            const Spacer(),
            const Text('💵 Cash', style: TextStyle(
              fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Un technicien sera envoyé en moins de 2h. Le paiement se fait en espèces après le service.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final data = ServiceData.categories[category]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vérifiez votre demande', style: TextStyle(
            fontSize: 16, color: AppTheme.textSecondary,
          )),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(data['icon'] as String, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['label'] as String, style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                        )),
                        Text(issueType, style: const TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary,
                        )),
                      ],
                    ),
                  ],
                ),
                const Divider(color: AppTheme.border, height: 24),
                _SummaryRow(icon: Icons.description_outlined, label: 'Description', value: description),
                const SizedBox(height: 10),
                _SummaryRow(icon: Icons.location_on_outlined, label: 'Adresse', value: '$address, $wilaya'),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SummaryRow(icon: Icons.photo_outlined, label: 'Photos', value: '${photos.length} photo(s) jointe(s)'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Price estimate
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.greenDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color.fromRGBO(46, 204, 113, 0.3)),
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimation du prix', style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary,
                    )),
                    Text('$priceMin – $priceMax DA', style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.green,
                    )),
                  ],
                ),
                const Spacer(),
                const Text('💵 Cash', style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Un technicien sera envoyé en moins de 2h. Le paiement se fait en espèces après le service.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
