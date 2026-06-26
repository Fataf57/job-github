import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import 'publication_page.dart';
import 'recruiter_profile_page.dart';
import 'register_page.dart';
import 'register_recruiter_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService api = ApiService();
  final AuthService authService = AuthService();
  final TextEditingController telephone = TextEditingController();
  final TextEditingController motDePasse = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    telephone.dispose();
    motDePasse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      // resizeToAvoidBottomInset: true (défaut) — le Scaffold gère le clavier
      // nativement via la contrainte de hauteur, sans aucun rebuild Flutter.
      body: Column(
        children: [
          // ── En-tête uni (fixe, ne bouge pas quand le clavier monte) ──
          Container(
            width: double.infinity,
            height: 260,
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.work_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'FASO JOB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Trouvez votre emploi idéal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // ── Formulaire scrollable — Expanded laisse Scaffold réduire la hauteur
          //    quand le clavier apparaît, SingleChildScrollView auto-scroll au champ ──
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bienvenue ! Entrez vos identifiants.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 28),

                    // Téléphone
                    TextFormField(
                      controller: telephone,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: _inputDecoration(
                        label: 'Téléphone',
                        icon: Icons.phone_outlined,
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Téléphone requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Mot de passe
                    TextFormField(
                      controller: motDePasse,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'Mot de passe',
                        icon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                    ),
                    const SizedBox(height: 20),

                    // Message d'erreur
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Color(0xFFDC2626), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Bouton connexion
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Lien inscription
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Pas encore de compte ? ",
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () => _showAccountTypeSheet(context),
                          child: const Text(
                            "Créer un compte",
                            style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  void _showAccountTypeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.paddingOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poignée
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Je suis…',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choisissez le type de compte à créer',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Option chercheur d'emploi
            _AccountTypeCard(
              icon: Icons.person_search_outlined,
              color: const Color(0xFF1565C0),
              title: 'Chercheur d\'emploi',
              subtitle: 'Je cherche un emploi ou une opportunité',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()));
              },
            ),
            const SizedBox(height: 12),

            // Option recruteur
            _AccountTypeCard(
              icon: Icons.business_center_outlined,
              color: const Color(0xFF0D47A1),
              title: 'Recruteur / Entreprise',
              subtitle: 'Je publie des offres et je recrute',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterRecruiterPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final user = await api.login(
        telephone: telephone.text,
        motDePasse: motDePasse.text,
      );
      if (user != null && mounted) {
        await authService.saveUser(user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => user.isRecruteur
                ? const RecruiterProfilePage()
                : const PublicationPage(),
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage =
              'Identifiants invalides. Vérifiez votre téléphone et mot de passe.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur de connexion : ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── Widget carte de choix du type de compte ───────────────────────────────────
class _AccountTypeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.04),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
