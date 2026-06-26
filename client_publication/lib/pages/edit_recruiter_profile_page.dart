import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

class EditRecruiterProfilePage extends StatefulWidget {
  final Utilisateur user;

  const EditRecruiterProfilePage({super.key, required this.user});

  @override
  State<EditRecruiterProfilePage> createState() =>
      _EditRecruiterProfilePageState();
}

class _EditRecruiterProfilePageState extends State<EditRecruiterProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ApiService _api = ApiService();

  late final TextEditingController _nomEntreprise;
  late final TextEditingController _secteurActivite;
  late final TextEditingController _description;
  late final TextEditingController _adresse;
  late final TextEditingController _siteWeb;
  late final TextEditingController _rccm;
  late final TextEditingController _nif;
  late final TextEditingController _telephone;
  late final TextEditingController _email;
  late final TextEditingController _localite;

  bool _submitting = false;
  String? _errorMessage;

  static const _secteurs = [
    'Technologie & Informatique',
    'Finance & Banque',
    'Santé & Médical',
    'Éducation & Formation',
    'Commerce & Distribution',
    'Agriculture & Agroalimentaire',
    'BTP & Immobilier',
    'Transport & Logistique',
    'Énergie & Mines',
    'Télécommunications',
    'Tourisme & Hôtellerie',
    'Média & Communication',
    'ONG & Association',
    'Administration Publique',
    'Autre',
  ];

  String? _selectedSecteur;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nomEntreprise = TextEditingController(text: u.nomEntreprise ?? '');
    _secteurActivite = TextEditingController(text: u.secteurActivite ?? '');
    _description = TextEditingController(text: u.descriptionEntreprise ?? '');
    _adresse = TextEditingController(text: u.adresseEntreprise ?? '');
    _siteWeb = TextEditingController(text: u.siteWeb ?? '');
    _rccm = TextEditingController(text: u.rccm ?? '');
    _nif = TextEditingController(text: u.nif ?? '');
    _telephone = TextEditingController(text: u.telephone);
    _email = TextEditingController(text: u.email);
    _localite = TextEditingController(text: u.localite ?? '');

    _selectedSecteur = _secteurs.contains(u.secteurActivite)
        ? u.secteurActivite
        : null;
  }

  @override
  void dispose() {
    _nomEntreprise.dispose();
    _secteurActivite.dispose();
    _description.dispose();
    _adresse.dispose();
    _siteWeb.dispose();
    _rccm.dispose();
    _nif.dispose();
    _telephone.dispose();
    _email.dispose();
    _localite.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final updated = Utilisateur(
        id: widget.user.id,
        nom: widget.user.nom,
        prenom: widget.user.prenom,
        email: _email.text.trim(),
        telephone: _telephone.text.trim(),
        motDePasse: widget.user.motDePasse,
        photoProfil: widget.user.photoProfil,
        role: widget.user.role,
        actif: widget.user.actif,
        localite: _localite.text.trim().isEmpty ? null : _localite.text.trim(),
        nomEntreprise: _nomEntreprise.text.trim().isEmpty
            ? null
            : _nomEntreprise.text.trim(),
        secteurActivite: _selectedSecteur,
        descriptionEntreprise: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        adresseEntreprise: _adresse.text.trim().isEmpty
            ? null
            : _adresse.text.trim(),
        siteWeb: _siteWeb.text.trim().isEmpty ? null : _siteWeb.text.trim(),
        rccm: _rccm.text.trim().isEmpty ? null : _rccm.text.trim(),
        nif: _nif.text.trim().isEmpty ? null : _nif.text.trim(),
      );

      final result = await _api.updateUser(updated.id!, updated.toJson());
      if (result != null) {
        await _authService.saveUser(result);
        if (mounted) Navigator.pop(context, result);
      } else {
        setState(() => _errorMessage = 'Échec de la mise à jour.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Modifier le profil',
          style: TextStyle(
              color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 340),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Informations entreprise ──
                      _SectionHeader(
                          icon: Icons.business_outlined,
                          title: 'Informations entreprise'),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _nomEntreprise,
                        label: 'Nom de l\'entreprise',
                        icon: Icons.business_center_outlined,
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      // Secteur d'activité (dropdown)
                      DropdownButtonFormField<String>(
                        value: _selectedSecteur,
                        decoration: _inputDecoration(
                          label: "Secteur d'activité",
                          icon: Icons.category_outlined,
                        ),
                        items: _secteurs
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedSecteur = v),
                        isExpanded: true,
                      ),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _description,
                        label: 'Description de l\'entreprise',
                        icon: Icons.description_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),

                      // ── Coordonnées ──
                      _SectionHeader(
                          icon: Icons.contact_phone_outlined,
                          title: 'Coordonnées'),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _telephone,
                        label: 'Téléphone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _email,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        required: true,
                      ),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _localite,
                        label: 'Localité / Ville',
                        icon: Icons.location_city_outlined,
                      ),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _adresse,
                        label: 'Adresse physique',
                        icon: Icons.home_outlined,
                      ),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _siteWeb,
                        label: 'Site web',
                        icon: Icons.language_outlined,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 20),

                      // ── Informations légales ──
                      _SectionHeader(
                          icon: Icons.gavel_outlined,
                          title: 'Informations légales'),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _rccm,
                        label: 'RCCM (optionnel)',
                        icon: Icons.description_outlined,
                      ),
                      const SizedBox(height: 12),

                      _buildField(
                        controller: _nif,
                        label: 'NIF (optionnel)',
                        icon: Icons.numbers_outlined,
                      ),
                      const SizedBox(height: 20),

                      // Erreur
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFFCA5A5)),
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
                                      color: Color(0xFFDC2626),
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Bouton enregistrer
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Enregistrer les modifications',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autofillHints: const <String>[],
      decoration: _inputDecoration(label: label, icon: icon),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label requis' : null
          : null,
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}
