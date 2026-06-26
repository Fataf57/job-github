import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF42A5F5);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService authService = AuthService();
  Utilisateur? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    try {
      final user = await authService.getCurrentUser();
      if (user != null) {
        setState(() => _currentUser = user);
      } else if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'utilisateur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Annuler', style: TextStyle(color: _kSubtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await authService.logout();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }
    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: Text('Aucun utilisateur connecté')),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── En-tête uni ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              left: 16,
              right: 16,
              bottom: 10,
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
                // Barre de navigation
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
                    const Spacer(),
                    Text(
                      _currentUser!.nomComplet,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const SizedBox(width: 36, height: 36),
                  ],
                ),
                const SizedBox(height: 8),

                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        backgroundImage: _currentUser!.photoProfil != null &&
                                _currentUser!.photoProfil!.isNotEmpty
                            ? NetworkImage(_currentUser!.photoProfil!)
                            : null,
                        child: _currentUser!.photoProfil == null ||
                                _currentUser!.photoProfil!.isEmpty
                            ? Text(
                                _initials(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  _currentUser!.email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),

                // Badges résumé
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentUser!.localite != null &&
                        _currentUser!.localite!.isNotEmpty)
                      _buildBadge(
                          Icons.location_on_outlined,
                          _currentUser!.localite!),
                  ],
                ),
              ],
            ),
          ),

          // ── Contenu ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                // Informations personnelles
                _sectionTitle('Informations personnelles',
                    Icons.person_outline, _kPrimary),
                const SizedBox(height: 10),
                _infoCard([
                  _infoRow(Icons.badge_outlined, 'Nom', _currentUser!.nom),
                  _divider(),
                  _infoRow(Icons.person_outline, 'Prénom', _currentUser!.prenom),
                  _divider(),
                  _infoRow(Icons.email_outlined, 'Email', _currentUser!.email),
                  _divider(),
                  _infoRow(
                      Icons.phone_outlined, 'Téléphone', _currentUser!.telephone),
                  _divider(),
                  _infoRow(Icons.wc_outlined, 'Sexe',
                      _currentUser!.sexe != null
                          ? (_currentUser!.sexe == 'M' ? 'Homme' : 'Femme')
                          : 'Non spécifié'),
                ]),
                const SizedBox(height: 20),

                // Domaines
                _sectionTitle('Domaines d\'études',
                    Icons.work_outline, _kPrimary),
                const SizedBox(height: 10),
                if (_currentUser!.domainesNiveaux.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: _kSubtext, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Aucun domaine sélectionné',
                          style: TextStyle(
                              color: _kSubtext,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                else
                  ..._currentUser!.domainesNiveaux.map((dn) =>
                      _domaineCard(dn)),
              ],
            ),
          ),
        ],
      ),

      // ── Bouton Modifier (flottant) ──
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: _kCard,
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, -3))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () async {
            final updatedUser = await Navigator.push<Utilisateur>(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfilePage(user: _currentUser!),
              ),
            );
            if (updatedUser != null && mounted) {
              setState(() => _currentUser = updatedUser);
            }
          },
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('Modifier le profil',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  String _initials() {
    final p =
        _currentUser!.prenom.isNotEmpty ? _currentUser!.prenom[0] : '';
    final n = _currentUser!.nom.isNotEmpty ? _currentUser!.nom[0] : '';
    return '${p.toUpperCase()}${n.toUpperCase()}';
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
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
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, color: _kBorder);

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kPrimary, size: 17),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: _kSubtext)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _domaineCard(DomaineNiveau dn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.work_outline,
                color: _kPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dn.domaine,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _kText)),
                if (dn.niveau != null && dn.niveau!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 12, color: _kSubtext),
                      const SizedBox(width: 4),
                      Text('Niveau : ${dn.niveau}',
                          style: const TextStyle(
                              fontSize: 12, color: _kSubtext)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_outlined,
                color: _kPrimary, size: 16),
          ),
        ],
      ),
    );
  }
}
