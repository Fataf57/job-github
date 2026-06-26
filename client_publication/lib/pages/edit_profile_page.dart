import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF42A5F5);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const List<String> _kNiveauxEtudes = [
  'Licence 1',
  'Licence 2',
  'Licence 3',
  'Master 1',
  'Master 2',
  'Doctorat',
];

class EditProfilePage extends StatefulWidget {
  final Utilisateur user;
  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ApiService api = ApiService();
  final AuthService authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  List<DomaineNiveau> _selectedDomainesNiveaux = [];

  final List<String> _availableDomaines = [
    'Informatique',
    'Comptabilité',
    'Marketing',
    'Ressources Humaines',
    'Finance',
    'Commerce',
    'Médecine',
    'Droit',
    'Ingénierie',
    'Éducation',
    'Agriculture',
    'Architecture',
    'Art',
    'Communication',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDomainesNiveaux = List.from(widget.user.domainesNiveaux);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: ID utilisateur manquant')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final domainesData = _selectedDomainesNiveaux
          .map((dn) => {
                'domaine': dn.domaine,
                if (dn.niveau != null && dn.niveau!.isNotEmpty)
                  'niveau': dn.niveau,
              })
          .toList();
      final updatedUser = await api.updateUser(widget.user.id!, {
        'domaines': domainesData,
      });
      if (!mounted) return;
      if (updatedUser != null) {
        await authService.updateCurrentUser(updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, updatedUser);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Échec de la mise à jour du profil'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── En-tête ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      child: Text(
                        _initials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit,
                          color: _kPrimary, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.user.prenom} ${widget.user.nom}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Formulaire ──
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                children: [
                  // Infos non modifiables
                  _buildSectionTitle('Informations personnelles',
                      Icons.person_outline, const Color(0xFF6B7280)),
                  _buildReadOnlyCard(),
                  const SizedBox(height: 20),

                  // Domaines
                  _buildSectionTitle('Domaines d\'études',
                      Icons.work_outline, _kPrimary),
                  const SizedBox(height: 10),
                  ..._selectedDomainesNiveaux.asMap().entries.map(
                        (e) => _buildDomaineNiveauCard(e.value, e.key),
                      ),
                  OutlinedButton.icon(
                    onPressed: _showDomaineSelectionDialog,
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
                  const SizedBox(height: 20),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: _kBg,
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kSubtext,
                    side: const BorderSide(color: _kBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials() {
    final p = widget.user.prenom.isNotEmpty ? widget.user.prenom[0] : '';
    final n = widget.user.nom.isNotEmpty ? widget.user.nom[0] : '';
    return '${p.toUpperCase()}${n.toUpperCase()}';
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kText)),
        ],
      ),
    );
  }

  Widget _buildReadOnlyCard() {
    final fields = [
      ('Nom', widget.user.nom, Icons.badge_outlined),
      ('Prénom', widget.user.prenom, Icons.person_outline),
      ('Email', widget.user.email, Icons.email_outlined),
      ('Téléphone', widget.user.telephone, Icons.phone_outlined),
      ('Sexe', widget.user.sexe ?? 'Non spécifié', Icons.wc_outlined),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: fields.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(f.$3, color: _kSubtext, size: 16),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.$1,
                        style: const TextStyle(
                            fontSize: 11, color: _kSubtext)),
                    Text(f.$2,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _kText)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDomaineNiveauCard(DomaineNiveau dn, int index) {
    return _DomaineNiveauCardWidget(
      domaineNiveau: dn,
      onDelete: () =>
          setState(() => _selectedDomainesNiveaux.removeAt(index)),
      onNiveauChanged: (niveau) =>
          setState(() => _selectedDomainesNiveaux[index].niveau = niveau),
    );
  }

  void _showDomaineSelectionDialog() {
    final selected = _selectedDomainesNiveaux.map((d) => d.domaine).toSet();
    final available =
        _availableDomaines.where((d) => !selected.contains(d)).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sélectionner un domaine',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: available.isEmpty
            ? const Text('Tous les domaines sont déjà sélectionnés',
                style: TextStyle(color: _kSubtext))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (ctx, i) => ListTile(
                    leading: const Icon(Icons.work_outline,
                        color: _kPrimary, size: 20),
                    title: Text(available[i],
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, color: _kText)),
                    onTap: () {
                      setState(() => _selectedDomainesNiveaux
                          .add(DomaineNiveau(domaine: available[i])));
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer',
                  style: TextStyle(color: _kSubtext))),
        ],
      ),
    );
  }
}

// ── Widget carte domaine/niveau ────────────────────────────────────────────
class _DomaineNiveauCardWidget extends StatefulWidget {
  final DomaineNiveau domaineNiveau;
  final VoidCallback onDelete;
  final Function(String?) onNiveauChanged;

  const _DomaineNiveauCardWidget({
    required this.domaineNiveau,
    required this.onDelete,
    required this.onNiveauChanged,
  });

  @override
  State<_DomaineNiveauCardWidget> createState() =>
      _DomaineNiveauCardWidgetState();
}

class _DomaineNiveauCardWidgetState extends State<_DomaineNiveauCardWidget> {
  String? _selectedNiveau;

  @override
  void initState() {
    super.initState();
    _selectedNiveau = widget.domaineNiveau.niveau;
  }

  @override
  Widget build(BuildContext context) {
    final niveauItems = List<String>.from(_kNiveauxEtudes);
    if (_selectedNiveau != null &&
        _selectedNiveau!.isNotEmpty &&
        !niveauItems.contains(_selectedNiveau)) {
      niveauItems.insert(0, _selectedNiveau!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.work_outline,
                    color: _kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.domaineNiveau.domaine,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _kText)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFDC2626), size: 20),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: (_selectedNiveau != null && _selectedNiveau!.isNotEmpty)
                ? _selectedNiveau
                : null,
            decoration: const InputDecoration(
              labelText: 'Niveau',
              hintText: 'Sélectionner un niveau',
              prefixIcon:
                  Icon(Icons.school_outlined, color: _kPrimary, size: 18),
              filled: true,
              fillColor: _kBg,
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _kBorder, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _kPrimary, width: 1.5),
              ),
            ),
            items: niveauItems
                .map((niveau) => DropdownMenuItem<String>(
                      value: niveau,
                      child: Text(niveau),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedNiveau = value);
              widget.onNiveauChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
