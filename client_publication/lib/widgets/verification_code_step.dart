import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/phone_utils.dart';
import '../pages/publication_page.dart';

const _kPrimary = Color(0xFF1565C0);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);

/// Étape de confirmation par code (6 chiffres) intégrée au flux d'inscription.
class VerificationCodeStep extends StatefulWidget {
  final String telephone;
  final String motDePasse;
  final String? email;
  final String? devCode;

  const VerificationCodeStep({
    super.key,
    required this.telephone,
    required this.motDePasse,
    this.email,
    this.devCode,
  });

  @override
  State<VerificationCodeStep> createState() => _VerificationCodeStepState();
}

class _VerificationCodeStepState extends State<VerificationCodeStep> {
  final ApiService _api = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  bool _verifying = false;
  bool _resending = false;
  int _countdown = 60;
  Timer? _timer;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _devCode = widget.devCode;
    _startCountdown();
    _otpController.addListener(() => setState(() {}));
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

  bool get _viaEmail => widget.email?.trim().isNotEmpty ?? false;

  String _masquerEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    if (local.length <= 2) return email;
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@${parts[1]}';
  }

  String _masquerTelephone(String telephone) {
    final normalized = normalizeTelephone(telephone);
    if (normalized.length <= 4) return normalized;
    return '${normalized.substring(0, normalized.length - 2).replaceAll(RegExp(r'.'), '*')}${normalized.substring(normalized.length - 2)}';
  }

  String get _destinationLabel {
    if (_viaEmail) return _masquerEmail(widget.email!.trim());
    return _masquerTelephone(widget.telephone);
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

    if (result['success'] == true) {
      setState(() {
        _devCode = result['verification_code'] as String? ?? _devCode;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['message'] ?? ''),
      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
    ));

    if (result['success'] == true) _startCountdown();
  }

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
                    ? Container(width: 2, height: 24, color: _kPrimary)
                    : null,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _viaEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined,
              color: _kPrimary,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Confirmation du compte',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _viaEmail
                ? 'Code envoyé à $_destinationLabel'
                : 'Code envoyé au $_destinationLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kSubtext, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Entrez le code à 6 chiffres pour activer votre compte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSubtext, fontSize: 13, height: 1.5),
          ),
          if (_devCode != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Code de test (affiché en attendant l’email)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _devCode!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
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
                if (_code.length == 6) _verifier();
              },
            ),
          ),
          _buildOtpDisplay(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_verifying || _code.length < 6) ? null : _verifier,
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
                      'Confirmer le code',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          _countdown > 0
              ? Text(
                  'Renvoyer le code dans $_countdown s',
                  style: const TextStyle(color: _kSubtext, fontSize: 13),
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
    );
  }
}
