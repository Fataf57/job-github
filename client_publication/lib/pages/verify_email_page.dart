import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../utils/phone_utils.dart';
import 'publication_page.dart';

const _kPrimary = Color(0xFF1565C0);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);

class VerifyEmailPage extends StatefulWidget {
  final String telephone;
  final String motDePasse;
  final String? email;

  const VerifyEmailPage({
    super.key,
    required this.telephone,
    required this.motDePasse,
    this.email,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final ApiService _api = ApiService();
  final AuthService _authService = AuthService();

  // Un seul TextField caché capte la saisie → zéro latence clavier sur mobile
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  bool _verifying = false;
  bool _resending = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _otpController.addListener(() => setState(() {}));
    // Ouvre le clavier automatiquement à l'arrivée sur la page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _code => _otpController.text;

  String _masquerTelephone(String telephone) {
    final normalized = normalizeTelephone(telephone);
    if (normalized.length <= 4) return normalized;
    return '${normalized.substring(0, normalized.length - 2).replaceAll(RegExp(r'.'), '*')}${normalized.substring(normalized.length - 2)}';
  }

  String get _destinationLabel {
    final email = widget.email?.trim() ?? '';
    if (email.isNotEmpty) return _masquerEmail(email);
    return _masquerTelephone(widget.telephone);
  }

  bool get _viaEmail => (widget.email?.trim().isNotEmpty ?? false);

  String _masquerEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    if (local.length <= 2) return email;
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@${parts[1]}';
  }

  Future<void> _connecterEtOuvrirPublications() async {
    final user = await _api.login(
      telephone: widget.telephone,
      motDePasse: widget.motDePasse,
    );
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Compte vérifié, mais connexion impossible.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    await _authService.saveUser(user);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PublicationPage()),
      (_) => false,
    );
  }

  Future<void> _verifier() async {
    if (_code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entrez les 6 chiffres du code.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    _otpFocus.unfocus();
    setState(() => _verifying = true);
    final result = await _api.verifyEmailCode(
      email: widget.email,
      telephone: widget.telephone,
      code: _code,
    );
    if (!mounted) return;
    setState(() => _verifying = false);

    if (result['success'] == true) {
      await _connecterEtOuvrirPublications();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Code incorrect.'),
        backgroundColor: Colors.red,
      ));
      _otpController.clear();
      _otpFocus.requestFocus();
    }
  }

  Future<void> _renvoyer() async {
    setState(() => _resending = true);
    final result = await _api.resendVerificationCode(
      email: widget.email,
      telephone: widget.telephone,
    );
    if (!mounted) return;
    setState(() => _resending = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? ''),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));

    if (result['success'] == true) _startCountdown();
  }

  // Cases visuelles — simples containers, aucun widget de saisie
  Widget _buildOtpDisplay() {
    final digits = _code.padRight(6);
    return GestureDetector(
      onTap: () => _otpFocus.requestFocus(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final isFocused = _otpFocus.hasFocus && _code.length == i;
          final hasDigit = i < _code.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 56,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused
                    ? _kPrimary
                    : hasDigit
                        ? _kPrimary.withOpacity(0.5)
                        : const Color(0xFFE5E7EB),
                width: isFocused ? 2 : 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: hasDigit
                ? Text(
                    digits[i],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                  )
                : isFocused
                    ? _Cursor()
                    : null,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // En-tête uni
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 28,
            ),
            decoration: const BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vérification du compte',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _viaEmail
                      ? 'Code envoyé à $_destinationLabel'
                      : 'Code envoyé au $_destinationLabel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Corps
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                children: [
                  // Icône
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read_outlined,
                        color: _kPrimary, size: 40),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Entrez le code à 6 chiffres',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Consultez votre boîte mail ou votre téléphone\net entrez le code pour activer votre compte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _kSubtext, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // TextField caché — capte la saisie sans afficher de curseur natif
                  SizedBox(
                    width: 0,
                    height: 0,
                    child: TextField(
                      controller: _otpController,
                      focusNode: _otpFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      showCursor: false,
                      onChanged: (_) {
                        // Lance la vérification automatique quand 6 chiffres saisis
                        if (_code.length == 6) _verifier();
                      },
                    ),
                  ),

                  // Affichage visuel OTP
                  _buildOtpDisplay(),
                  const SizedBox(height: 36),

                  // Bouton Vérifier
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_verifying || _code.length < 6) ? null : _verifier,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kPrimary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: _verifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Vérifier le code',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Renvoyer le code
                  _countdown > 0
                      ? Text(
                          'Renvoyer le code dans $_countdown s',
                          style:
                              const TextStyle(color: _kSubtext, fontSize: 13),
                        )
                      : TextButton(
                          onPressed: _resending ? null : _renvoyer,
                          child: _resending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _kPrimary),
                                )
                              : const Text(
                                  'Renvoyer le code',
                                  style: TextStyle(
                                    color: _kPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Curseur clignotant pour la case active
class _Cursor extends StatefulWidget {
  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 24,
        color: _kPrimary,
      ),
    );
  }
}
