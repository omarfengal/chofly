import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/providers.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_extensions.dart';
import '../../widgets/common_widgets.dart';
import '../../config/app_config.dart';

// ════════════════════════════════════════════════════════════════
// PHONE INPUT SCREEN  [#8 — OTP rate limit côté client]
// ════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _agreed = false;
  bool _isRateLimited = false;
  int _rateLimitCooldown = 0;

  // [#8] OTP rate limit: max 3 envois / session, puis cooldown 120s
  int _otpSentCount = 0;
  static const int _maxOtpPerSession = 3;
  static const int _cooldownSeconds = 120;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // [#8] Démarre le cooldown visuel si limite atteinte
  void _startRateLimitCooldown() {
    setState(() {
      _isRateLimited = true;
      _rateLimitCooldown = _cooldownSeconds;
    });
    _tickCooldown();
  }

  void _tickCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_rateLimitCooldown > 1) {
        setState(() => _rateLimitCooldown--);
        _tickCooldown();
      } else {
        setState(() {
          _isRateLimited = false;
          _rateLimitCooldown = 0;
          _otpSentCount = 0; // reset après cooldown
        });
      }
    });
  }

  Future<void> _sendOTP() async {
    // [#8] Guard côté client
    if (_isRateLimited) return;
    if (_otpSentCount >= _maxOtpPerSession) {
      _startRateLimitCooldown();
      return;
    }

    final phone = _phoneController.text.trim();
    final cleanPhone = phone.replaceAll(' ', '');
    if (!cleanPhone.isValidAlgerianPhone) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Numéro invalide. Ex: 0661 234 567'),
        backgroundColor: AppTheme.red,
      ));
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez accepter les conditions'),
      ));
      return;
    }

    String formatted = phone.replaceAll(' ', '');
    if (formatted.startsWith('0')) {
      formatted = '+213${formatted.substring(1)}';
    } else if (!formatted.startsWith('+')) {
      formatted = '+213$formatted';
    }

    setState(() => _otpSentCount++);

    context.read<AuthProvider>().sendOTP(
      formatted,
      (verificationId) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OTPScreen(phone: formatted),
        ));
      },
      (error) {
        if (!mounted) return;
        // [#8] Si erreur Firebase (trop de requêtes), déclencher cooldown
        if (error.toLowerCase().contains('too-many-requests') ||
            error.toLowerCase().contains('quota')) {
          _startRateLimitCooldown();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $error'),
          backgroundColor: AppTheme.red,
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Check referral arg (from onboarding "Je suis artisan")
    final args = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            // Logo
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.green, AppTheme.greenDark]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('✦',
                    style: TextStyle(fontSize: 22, color: Colors.white))),
              ),
              const SizedBox(width: 10),
              const Text('CHOFLY', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary, letterSpacing: 2,
              )),
            ]),
            const SizedBox(height: 44),
            const Text('Bienvenue 👋', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(
              args == 'provider'
                  ? 'Espace artisan — entrez votre numéro'
                  : 'Entrez votre numéro pour continuer',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),

            // Phone field label
            const Text('Numéro de téléphone', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),

            // Phone input
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppTheme.border))),
                  child: const Row(children: [
                    Text('🇩🇿', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 6),
                    Text('+213', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ]),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    style: const TextStyle(
                      fontSize: 16, color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600, letterSpacing: 1.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      hintText: '0661 234 567',
                      counterText: '',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 15, letterSpacing: 0),
                      filled: false,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Terms checkbox
            GestureDetector(
              onTap: () => setState(() => _agreed = !_agreed),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _agreed ? AppTheme.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _agreed ? AppTheme.green : AppTheme.border2,
                      width: 1.5,
                    ),
                  ),
                  child: _agreed
                    ? const Icon(Icons.check_rounded, size: 14, color: AppTheme.bg)
                    : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: RichText(text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  children: [
                    const TextSpan(text: "J'accepte les "),
                    TextSpan(
                      text: "conditions d'utilisation",
                      style: const TextStyle(
                        color: AppTheme.green,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = () =>
                          launchUrl(Uri.parse(AppConfig.cguUrl),
                              mode: LaunchMode.externalApplication),
                    ),
                    const TextSpan(text: " et la "),
                    TextSpan(
                      text: "politique de confidentialité",
                      style: const TextStyle(
                        color: AppTheme.green,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = () =>
                          launchUrl(Uri.parse(AppConfig.privacyUrl),
                              mode: LaunchMode.externalApplication),
                    ),
                  ],
                ))),
              ]),
            ),
            const SizedBox(height: 28),

            // [#8] Rate limit banner
            if (_isRateLimited) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.redDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.redBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppTheme.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Trop de tentatives. Réessayez dans ${_rateLimitCooldown}s',
                    style: const TextStyle(fontSize: 12, color: AppTheme.red),
                  )),
                ]),
              ),
            ],

            // Remaining attempts hint
            if (!_isRateLimited && _otpSentCount > 0) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${_maxOtpPerSession - _otpSentCount} envoi(s) restant(s)',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // CTA button
            ChoflyButton(
              label: auth.isLoading ? 'Envoi en cours…' : 'Recevoir le code OTP',
              onPressed: (auth.isLoading || _isRateLimited) ? null : _sendOTP,
              isLoading: auth.isLoading,
            ),
            const SizedBox(height: 22),
            const Center(child: Text(
              'Vous recevrez un SMS de vérification\nà ce numéro',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.6),
              textAlign: TextAlign.center,
            )),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// OTP SCREEN
// ════════════════════════════════════════════════════════════════
class OTPScreen extends StatefulWidget {
  final String phone;
  const OTPScreen({super.key, required this.phone});
  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
        _startCountdown();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  Future<void> _verify() async {
    if (_otpController.text.length < 6) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOTP(_otpController.text);
    if (!mounted) return;

    if (success) {
      if (auth.userModel == null) {
        Navigator.of(context).pushReplacementNamed('/setup-profile');
      } else if (auth.isAdmin) {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else if (auth.isProvider) {
        Navigator.of(context).pushReplacementNamed('/provider/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/customer/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? 'Code incorrect'),
        backgroundColor: AppTheme.red,
      ));
    }
  }

  final _defaultPinTheme = PinTheme(
    width: 54, height: 60,
    textStyle: const TextStyle(
        fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.card, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 36),
            const Text('Vérification 📱', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Code envoyé au ${widget.phone}',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 36),
            Center(
              child: Pinput(
                length: 6,
                controller: _otpController,
                autofocus: true,
                onCompleted: (_) => _verify(),
                defaultPinTheme: _defaultPinTheme,
                focusedPinTheme: _defaultPinTheme.copyDecorationWith(
                  border: Border.all(color: AppTheme.green, width: 2)),
                submittedPinTheme: _defaultPinTheme.copyDecorationWith(
                  color: AppTheme.greenDim,
                  border: Border.all(color: AppTheme.green)),
              ),
            ),
            const SizedBox(height: 28),
            ChoflyButton(
              label: auth.isLoading ? 'Vérification…' : 'Confirmer',
              onPressed: auth.isLoading ? null : _verify,
              isLoading: auth.isLoading,
            ),
            const SizedBox(height: 18),
            Center(
              child: _canResend
                ? TextButton(
                    onPressed: () {
                      setState(() { _countdown = 60; _canResend = false; });
                      _startCountdown();
                      context.read<AuthProvider>().sendOTP(widget.phone, (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code renvoyé ✓')));
                      }, (e) {});
                    },
                    child: const Text('Renvoyer le code',
                      style: TextStyle(color: AppTheme.green, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  )
                : Text('Renvoyer dans ${_countdown}s',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SETUP PROFILE SCREEN
// ════════════════════════════════════════════════════════════════
class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});
  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  final _referralService = ReferralService();
  String _selectedRole = 'customer';
  String? _selectedWilaya;
  bool _showReferralField = false;

  @override
  void dispose() {
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez votre nom')));
      return;
    }
    if (_selectedWilaya == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez votre wilaya')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = UserModel(
      uid: auth.firebaseUser!.uid,
      phone: auth.firebaseUser!.phoneNumber ?? '',
      name: _nameController.text.trim(),
      role: _selectedRole,
      wilaya: _selectedWilaya,
      createdAt: DateTime.now(),
    );
    await auth.createProfile(user);

    // [#10] Apply referral code if provided
    final refCode = _referralController.text.trim();
    if (refCode.isNotEmpty) {
      await _referralService.applyReferral(
        refereeId: user.uid,
        refereeName: user.name,
        refereePhone: user.phone,
        referralCode: refCode,
      );
    }

    if (!mounted) return;
    if (_selectedRole == 'provider') {
      Navigator.of(context).pushReplacementNamed('/provider/setup');
    } else {
      Navigator.of(context).pushReplacementNamed('/customer/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            const Text('Votre profil ✨', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('Complétez votre profil pour commencer',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 32),

            // Name
            const Text('Nom complet', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'ex: Omar Benali',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 18),

            // Wilaya
            const Text('Wilaya', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedWilaya,
                  isExpanded: true,
                  hint: const Text('Choisir la wilaya',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                  dropdownColor: AppTheme.card2,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                  items: ServiceData.wilayas.map((w) => DropdownMenuItem(
                    value: w, child: Text(w))).toList(),
                  onChanged: (v) => setState(() => _selectedWilaya = v),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Role
            const Text('Vous êtes :', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _RoleCard(
                emoji: '🏠', title: 'Client',
                subtitle: 'Je cherche un artisan',
                isSelected: _selectedRole == 'customer',
                onTap: () => setState(() => _selectedRole = 'customer'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _RoleCard(
                emoji: '🔧', title: 'Artisan',
                subtitle: 'Je propose mes services',
                isSelected: _selectedRole == 'provider',
                onTap: () => setState(() => _selectedRole = 'provider'),
              )),
            ]),
            const SizedBox(height: 20),

            // [#10] Referral code field
            GestureDetector(
              onTap: () => setState(() => _showReferralField = !_showReferralField),
              child: Row(children: [
                const Icon(Icons.card_giftcard_rounded, size: 16, color: AppTheme.green),
                const SizedBox(width: 6),
                const Text('J\'ai un code parrainage',
                  style: TextStyle(fontSize: 13, color: AppTheme.green,
                      fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(_showReferralField
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AppTheme.green),
              ]),
            ),
            if (_showReferralField) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _referralController,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                    letterSpacing: 1, fontWeight: FontWeight.w600),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'ex: CHO-AB12CD',
                  prefixIcon: Icon(Icons.tag_rounded, color: AppTheme.textMuted),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ChoflyButton(label: 'Continuer', onPressed: _continue),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _RoleCard({required this.emoji, required this.title,
    required this.subtitle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.greenDim : AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.green : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: isSelected ? AppTheme.green : AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(
            fontSize: 11, color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
