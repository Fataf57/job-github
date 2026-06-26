import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../services/publication_service.dart';
import '../widgets/verification_code_step.dart';

// ── Couleurs de l'app ──────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF42A5F5);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final PageController _pageController = PageController(initialPage: 0);
  final _formKeyPage1 = GlobalKey<FormState>();
  final _formKeyPage2 = GlobalKey<FormState>();
  final ApiService api = ApiService();
  final PublicationService _publicationService = PublicationService();
  bool _submitting = false;
  String? _verificationCode;
  bool _isLoadingDomaines = true;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  int _currentPage = 0;

  final TextEditingController nom = TextEditingController();
  final TextEditingController prenom = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController telephone = TextEditingController();
  final TextEditingController motDePasse = TextEditingController();
  final TextEditingController confirmationMotDePasse = TextEditingController();
  String? _selectedSexe;

  final TextEditingController localite = TextEditingController();
  List<DomaineNiveau> _domainesNiveaux = [];
  List<String> _availableDomaines = [];

  @override
  void initState() {
    super.initState();
    _loadDomaines();
  }

  @override
  void dispose() {
    _pageController.dispose();
    nom.dispose();
    prenom.dispose();
    email.dispose();
    telephone.dispose();
    motDePasse.dispose();
    confirmationMotDePasse.dispose();
    localite.dispose();
    super.dispose();
  }

  Future<void> _loadDomaines() async {
    try {
      final ref = await _publicationService.fetchReferenceLists();
      setState(() {
        _availableDomaines = ref.domaines;
        _isLoadingDomaines = false;
      });
    } catch (e) {
      setState(() {
        _availableDomaines = [
          'INFORMATIQUE',
          'FINANCE COMPTABILITÉ',
          'ELECTRICITÉ',
          'ELECTRONIQUE',
          'DROIT'
        ];
        _isLoadingDomaines = false;
      });
    }
  }

  String? _validatePage1() {
    if (nom.text.trim().isEmpty) return 'Le nom est requis';
    if (prenom.text.trim().isEmpty) return 'Le prénom est requis';
    if (email.text.trim().isEmpty) return 'L\'email est requis';
    if (!email.text.trim().contains('@')) return 'L\'email est invalide';
    if (telephone.text.trim().isEmpty) return 'Le téléphone est requis';
    if (motDePasse.text.isEmpty) return 'Le mot de passe est requis';
    if (!RegExp(r'^\d+$').hasMatch(motDePasse.text))
      return 'Le mot de passe doit contenir uniquement des chiffres';
    if (motDePasse.text.length < 4)
      return 'Le mot de passe doit contenir au moins 4 chiffres';
    if (confirmationMotDePasse.text != motDePasse.text)
      return 'Les mots de passe ne correspondent pas';
    return null;
  }

  Future<void> _createAccount({bool skipProfessionalInfo = false}) async {
    final page1Error = _validatePage1();
    if (page1Error != null) {
      if (_currentPage == 1) {
        _pageController.animateToPage(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
        setState(() => _currentPage = 0);
        await Future.delayed(const Duration(milliseconds: 350));
        _formKeyPage1.currentState?.validate();
      } else {
        _formKeyPage1.currentState?.validate();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(page1Error),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }

    if (_currentPage == 1 && !skipProfessionalInfo) {
      if (_formKeyPage2.currentState != null &&
          !_formKeyPage2.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Veuillez corriger les erreurs dans le formulaire"),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final u = Utilisateur(
        nom: nom.text.trim(),
        prenom: prenom.text.trim(),
        email: email.text.trim(),
        telephone: telephone.text.trim(),
        motDePasse: motDePasse.text,
        sexe: _selectedSexe,
        localite: skipProfessionalInfo || localite.text.trim().isEmpty
            ? null
            : localite.text.trim(),
      );
      if (!skipProfessionalInfo) u.domainesNiveaux = _domainesNiveaux;

      final result = await api.registerUser(u);
      if (result['success'] == true && mounted) {
        _verificationCode = result['verification_code'] as String?;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? "Erreur lors de la création"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur réseau: $e")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _nextPage() {
    if (_formKeyPage1.currentState!.validate()) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _previousPage() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      // resizeToAvoidBottomInset: true (défaut) — le Scaffold gère le clavier.
      body: Column(
        children: [
          // ── En-tête uni ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
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
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Créer un compte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
            Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(1, _currentPage >= 0),
                    _buildStepConnector(_currentPage >= 1),
                    _buildStepIndicator(2, _currentPage >= 1),
                    _buildStepConnector(_currentPage >= 2),
                    _buildStepIndicator(3, _currentPage >= 2),
                  ],
                ),
              ],
            ),
          ),

          // ── Contenu ──
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalInfoPage(),
                _buildProfessionalInfoPage(),
                _buildVerificationPage(),
              ],
            ),
          ),

          // ── Barre de navigation ──
          _buildBottomBar(),
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

  Widget _buildStepConnector(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: active
            ? Colors.white
            : Colors.white.withOpacity(0.3),
      ),
    );
  }

  InputDecoration _inputDec(
      {required String label, required IconData icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _kPrimary, size: 20),
      filled: true,
      fillColor: _kCard,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Form(
        key: _formKeyPage1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations personnelles',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kText)),
            const SizedBox(height: 4),
            const Text('Remplissez vos informations de base',
                style: TextStyle(color: _kSubtext, fontSize: 13)),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: nom,
                  decoration: _inputDec(label: 'Nom *', icon: Icons.person_outline),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: prenom,
                  decoration:
                      _inputDec(label: 'Prénom *', icon: Icons.person_outline),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
            ]),
            const SizedBox(height: 14),

            TextFormField(
              controller: email,
              decoration:
                  _inputDec(label: 'Email *', icon: Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: telephone,
              decoration: _inputDec(
                  label: 'Téléphone *', icon: Icons.phone_outlined),
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

            DropdownButtonFormField<String>(
              value: _selectedSexe,
              decoration: _inputDec(
                      label: 'Sexe (optionnel)', icon: Icons.wc_outlined)
                  .copyWith(prefixIcon: null),
              hint: const Text('Sélectionner'),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Homme')),
                DropdownMenuItem(value: 'F', child: Text('Femme')),
              ],
              onChanged: (v) => setState(() => _selectedSexe = v),
            ),
            const SizedBox(height: 20),

            Container(
              height: 1,
              color: _kBorder,
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
            const SizedBox(height: 16),

            const Text('Sécurité',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kText)),
            const SizedBox(height: 12),

            TextFormField(
              controller: motDePasse,
              obscureText: _obscurePwd,
              keyboardType: TextInputType.number,
              decoration: _inputDec(
                      label: 'Mot de passe *',
                      icon: Icons.lock_outline,
                      hint: 'Minimum 4 chiffres')
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePwd
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _kSubtext,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePwd = !_obscurePwd),
                ),
              ),
              onChanged: (_) {
                if (confirmationMotDePasse.text.isNotEmpty)
                  _formKeyPage1.currentState?.validate();
              },
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                if (!RegExp(r'^\d+$').hasMatch(v))
                  return 'Uniquement des chiffres';
                if (v.length < 4) return 'Au moins 4 chiffres';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: confirmationMotDePasse,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              decoration: _inputDec(
                      label: 'Confirmer le mot de passe *',
                      icon: Icons.lock_outline)
                  .copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _kSubtext,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmation requise';
                if (v != motDePasse.text) return 'Mots de passe différents';
                return null;
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Form(
        key: _formKeyPage2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profil professionnel',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kText)),
            const SizedBox(height: 4),
            const Text('Ces informations sont optionnelles',
                style: TextStyle(color: _kSubtext, fontSize: 13)),
            const SizedBox(height: 20),

            // Domaines
            const Text('Domaines d\'études',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kText)),
            const SizedBox(height: 10),
            if (_isLoadingDomaines)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_domainesNiveaux.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: _kSubtext, size: 18),
                      SizedBox(width: 8),
                      Text('Aucun domaine ajouté',
                          style: TextStyle(
                              color: _kSubtext,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
              else
                ..._domainesNiveaux.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dn = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.work_outline,
                              color: _kPrimary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dn.domaine,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _kText)),
                              if (dn.niveau != null && dn.niveau!.isNotEmpty)
                                Text('Niveau : ${dn.niveau}',
                                    style: const TextStyle(
                                        color: _kSubtext, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFDC2626), size: 20),
                          onPressed: () =>
                              setState(() => _domainesNiveaux.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showDomaineNiveauDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un domaine'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
            const SizedBox(height: 20),

            TextFormField(
              controller: localite,
              decoration: _inputDec(
                label: 'Localité',
                icon: Icons.location_on_outlined,
                hint: 'Ex: Ouagadougou, Bobo-Dioulasso',
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationPage() {
    final emailValue = email.text.trim();
    return VerificationCodeStep(
      telephone: telephone.text.trim(),
      motDePasse: motDePasse.text,
      email: emailValue.isNotEmpty ? emailValue : null,
      devCode: _verificationCode,
    );
  }

  Widget _buildBottomBar() {
    if (_currentPage >= 2) return const SizedBox.shrink();

    // Scaffold gère l'espace clavier — on garde seulement le safe area du bas.
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, safeBottom + 12),
      decoration: const BoxDecoration(
        color: _kCard,
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          if (_currentPage == 1)
            OutlinedButton.icon(
              onPressed: _submitting ? null : _previousPage,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Retour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          if (_currentPage == 1) const SizedBox(width: 10),
          if (_currentPage == 0)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _nextPage,
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
              ),
            )
          else ...[
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => _createAccount(skipProfessionalInfo: true),
              child: const Text('Passer',
                  style: TextStyle(color: _kSubtext)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () => _createAccount(skipProfessionalInfo: false),
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
        ],
      ),
    );
  }

  void _showDomaineNiveauDialog() {
    String? selectedDomaine;
    final niveauCtrl = TextEditingController();
    final available = _availableDomaines
        .where((d) => !_domainesNiveaux.any((dn) => dn.domaine == d))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter un domaine',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Domaine :',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: _kText)),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  const Text('Tous les domaines sont ajoutés',
                      style: TextStyle(color: _kSubtext))
                else
                  DropdownButtonFormField<String>(
                    value: selectedDomaine,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      hintText: 'Choisir un domaine',
                    ),
                    items: available
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDlg(() => selectedDomaine = v),
                  ),
                const SizedBox(height: 16),
                const Text('Niveau (optionnel) :',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: _kText)),
                const SizedBox(height: 8),
                TextField(
                  controller: niveauCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _kBg,
                    hintText: 'Ex: BAC, BEPC, LICENCE',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                niveauCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Annuler', style: TextStyle(color: _kSubtext)),
            ),
            ElevatedButton(
              onPressed: selectedDomaine == null
                  ? null
                  : () {
                      setState(() {
                        _domainesNiveaux.add(DomaineNiveau(
                          domaine: selectedDomaine!,
                          niveau: niveauCtrl.text.trim().isEmpty
                              ? null
                              : niveauCtrl.text.trim(),
                        ));
                      });
                      niveauCtrl.dispose();
                      Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
