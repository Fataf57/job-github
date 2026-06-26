import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/verification_code_step.dart';

const _kPrimary = Color(0xFF1565C0);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

const _kSecteurs = [
  'Agriculture / Agroalimentaire',
  'BTP / Construction',
  'Commerce / Distribution',
  'Education / Formation',
  'Finance / Banque / Assurance',
  'Hôtellerie / Restauration / Tourisme',
  'Industrie / Manufacture',
  'Informatique / Télécommunications',
  'Logistique / Transport',
  'Médias / Communication',
  'ONG / Association',
  'Santé / Pharmacie',
  'Sécurité / Gardiennage',
  'Services aux entreprises',
  'Autre',
];

/// Grandes villes du Burkina Faso
const _kVillesBurkina = [
  'Banfora',
  'Bobo-Dioulasso',
  'Dédougou',
  'Djibo',
  'Dori',
  'Fada N\'Gourma',
  'Gaoua',
  'Garango',
  'Houndé',
  'Kaya',
  'Kombissiri',
  'Koudougou',
  'Koupéla',
  'Manga',
  'Ouagadougou',
  'Ouahigouya',
  'Réo',
  'Tenkodogo',
  'Yako',
  'Ziniaré',
];

class RegisterRecruiterPage extends StatefulWidget {
  const RegisterRecruiterPage({super.key});

  @override
  State<RegisterRecruiterPage> createState() => _RegisterRecruiterPageState();
}

class _RegisterRecruiterPageState extends State<RegisterRecruiterPage> {
  final PageController _pageController = PageController();
  final ApiService _api = ApiService();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  bool _submitting = false;
  String? _verificationCode;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  int _currentPage = 0;

  final _nomEntreprise = TextEditingController();
  String? _secteurActivite;
  String? _ville;
  final _telephone = TextEditingController();
  final _email = TextEditingController();

  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nomEntreprise.dispose();
    _telephone.dispose();
    _email.dispose();
    _motDePasse.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _goNext(GlobalKey<FormState> formKey) {
    if (formKey.currentState!.validate()) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goBack() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _createAccount() async {
    if (!_formKey2.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final email = _email.text.trim();
      final u = Utilisateur(
        email: email,
        telephone: _telephone.text.trim(),
        motDePasse: _motDePasse.text,
        role: 'RECRUTEUR',
        localite: _ville,
        nomEntreprise: _nomEntreprise.text.trim(),
        secteurActivite: _secteurActivite,
      );

      final result = await _api.registerUser(u);
      if (!mounted) return;

      if (result['success'] == true) {
        _verificationCode = result['verification_code'] as String?;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Erreur lors de la création'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur réseau: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 16,
        right: 16,
        bottom: 20,
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
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Compte Recruteur',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIndicator(1, _currentPage >= 0),
              _buildConnector(_currentPage >= 1),
              _buildStepIndicator(2, _currentPage >= 1),
              _buildConnector(_currentPage >= 2),
              _buildStepIndicator(3, _currentPage >= 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int n, bool active) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$n',
          style: TextStyle(
            color: active ? _kPrimary : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildConnector(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: active ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  InputDecoration _inputDec({
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
  }) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _kPrimary, size: 20),
      filled: true,
      fillColor: _kCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identité de l\'entreprise',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _kText),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomEntreprise,
              decoration: _inputDec(
                  label: 'Nom de l\'entreprise',
                  icon: Icons.business_outlined,
                  required: true),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom de l\'entreprise requis' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _secteurActivite,
              decoration: _inputDec(
                      label: 'Secteur d\'activité',
                      icon: Icons.category_outlined,
                      required: true)
                  .copyWith(prefixIcon: null),
              hint: const Text('Choisir un secteur'),
              isExpanded: true,
              items: _kSecteurs
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _secteurActivite = v),
              validator: (v) => v == null ? 'Secteur requis' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _ville,
              decoration: _inputDec(
                label: 'Ville / Localité',
                icon: Icons.location_on_outlined,
              ).copyWith(prefixIcon: null),
              hint: const Text('Choisir une ville (optionnel)'),
              isExpanded: true,
              items: _kVillesBurkina
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _ville = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telephone,
              decoration: _inputDec(
                  label: 'Téléphone',
                  icon: Icons.phone_outlined,
                  hint: 'Ex: 70 00 00 00',
                  required: true),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Téléphone requis' : null,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Un numéro = un seul compte. Si ce numéro a déjà un compte, connectez-vous.',
                style: TextStyle(fontSize: 12, color: _kSubtext),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: _inputDec(
                label: 'Email professionnel',
                icon: Icons.email_outlined,
                hint: 'Optionnel',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    final email = _email.text.trim();
    return VerificationCodeStep(
      telephone: _telephone.text.trim(),
      motDePasse: _motDePasse.text,
      email: email.isNotEmpty ? email : null,
      devCode: _verificationCode,
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Code secret',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _kText),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outlined, color: _kPrimary, size: 36),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _kPrimary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Le code doit contenir uniquement des chiffres (minimum 4).',
                      style: TextStyle(color: _kPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: _motDePasse,
              obscureText: _obscurePwd,
              keyboardType: TextInputType.number,
              decoration: _inputDec(
                      label: 'Code secret', icon: Icons.lock_outline, required: true)
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _kSubtext,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                ),
              ),
              onChanged: (_) {
                if (_confirmation.text.isNotEmpty) _formKey2.currentState?.validate();
              },
              validator: (v) {
                if (v == null || v.isEmpty) return 'Code requis';
                if (!RegExp(r'^\d+$').hasMatch(v)) return 'Uniquement des chiffres';
                if (v.length < 4) return 'Au moins 4 chiffres';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmation,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              decoration: _inputDec(
                      label: 'Confirmer le code', icon: Icons.lock_outline, required: true)
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _kSubtext,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation requise';
                if (v != _motDePasse.text) return 'Les codes ne correspondent pas';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_currentPage >= 2) return const SizedBox.shrink();

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, safeBottom + 12),
      decoration: const BoxDecoration(
        color: _kCard,
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            OutlinedButton.icon(
              onPressed: _submitting ? null : _goBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Retour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _currentPage == 0
                ? ElevatedButton.icon(
                    onPressed: _submitting ? null : () => _goNext(_formKey1),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Suivant',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _submitting ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Créer le compte',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
    );
  }
}
