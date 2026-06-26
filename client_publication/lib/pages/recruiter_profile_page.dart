import 'package:flutter/material.dart';
import '../models/publication.dart';
import '../models/user_model.dart' as user_model;
import '../services/publication_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/image_carousel.dart';
import 'create_publication_page.dart';
import 'edit_recruiter_profile_page.dart';
import 'publication_page.dart';

String _resolveImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  if (path.startsWith('/')) return '${Constants.baseUrl}$path';
  return '${Constants.baseUrl}/media/publications/$path';
}

const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF42A5F5);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class RecruiterProfilePage extends StatefulWidget {
  const RecruiterProfilePage({super.key});

  @override
  State<RecruiterProfilePage> createState() => _RecruiterProfilePageState();
}

class _RecruiterProfilePageState extends State<RecruiterProfilePage> {
  final AuthService _authService = AuthService();
  final PublicationService _service = PublicationService();
  user_model.Utilisateur? _user;
  int _selectedTab = 0; // 0=Offres en cours, 1=Historique, 2=Informations
  List<Publication> _enCours = [];
  List<Publication> _historique = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await _authService.getCurrentUser();
    if (mounted) {
      setState(() => _user = u);
      if (u != null) _loadOffres(u);
    }
  }

  Future<void> _loadOffres(user_model.Utilisateur u) async {
    if (u.id == null) return;
    setState(() => _loading = true);
    try {
      final result = await _service.fetchPublicationsByAuteur(
          u.id!, page: 1, pageSize: 200);
      if (!mounted) return;
      final now = DateTime.now();
      final enCours = <Publication>[];
      final historique = <Publication>[];
      for (final p in result.results) {
        final exp =
            p.dateLimite != null ? DateTime.tryParse(p.dateLimite!) : null;
        (exp == null || exp.isAfter(now) ? enCours : historique).add(p);
      }
      setState(() {
        _enCours = enCours;
        _historique = historique;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onProfileUpdated(user_model.Utilisateur u) async {
    await _authService.saveUser(u);
    if (mounted) {
      setState(() => _user = u);
      _loadOffres(u);
    }
  }

  Future<void> _delete(Publication pub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'offre'),
        content: Text('Supprimer "${pub.titre}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || pub.id == null) return;
    final ok = await _service.deletePublication(pub.id!);
    if (ok && mounted) _loadOffres(_user!);
  }

  String _initials() {
    final company = _user!.nomEntreprise ?? _user!.email;
    final parts = company.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return company.isNotEmpty ? company[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final company = _user!.nomEntreprise ?? _user!.email;

    final bottomPad = MediaQuery.of(context).padding.bottom + 16;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
        Column(
        children: [
          // ── En-tête uni ──
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
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: Text(_initials(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(company,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(_user!.email,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),

          // ── Trois boutons onglets ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _tabBtn(0, 'Mes offres', _enCours.length),
                const SizedBox(width: 8),
                _tabBtn(1, 'Historique', _historique.length),
                const SizedBox(width: 8),
                _tabBtn(2, 'Informations', null),
              ],
            ),
          ),

          // ── Contenu selon onglet ──
          Expanded(
            child: _loading && _selectedTab != 2
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary))
                : _selectedTab == 2
                    ? _buildInfoTab()
                    : _buildOffresTab(),
          ),
        ],
      ),
        // ── FAB gauche : Voir les publications ──
        if (_selectedTab != 2)
          Positioned(
            bottom: bottomPad,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_voir',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PublicationPage(showBackButton: true)),
              ),
              backgroundColor: Colors.white,
              foregroundColor: _kPrimary,
              elevation: 3,
              label: const Text('Voir les publications',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        // ── FAB droit : Publier ──
        if (_selectedTab != 2)
          Positioned(
            bottom: bottomPad,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_publier',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreatePublicationPage()),
                );
                _loadOffres(_user!);
              },
              backgroundColor: _kPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Publier',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
      ]), // fin Stack
      bottomNavigationBar: _selectedTab == 2
          ? Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
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
                  final updated =
                      await Navigator.push<user_model.Utilisateur>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            EditRecruiterProfilePage(user: _user!)),
                  );
                  if (updated != null) _onProfileUpdated(updated);
                },
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Modifier le profil',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            )
          : null,
    );
  }

  Widget _tabBtn(int index, String label, int? count) {
    final selected = _selectedTab == index;
    final displayText = count != null ? '$label ($count)' : label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? _kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _kPrimary : _kBorder,
            ),
            boxShadow: selected
                ? [BoxShadow(
                    color: _kPrimary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              displayText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _kSubtext),
            ),
          ),
        ),
      ),
    );
  }

  void _showOffreModal(Publication pub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Container(
          height: screenHeight * 0.80,
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Poignée (décorative uniquement)
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // En-tête modal
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.work_outline,
                          color: _kPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pub.titre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _kText),
                              maxLines: 2),
                          const SizedBox(height: 2),
                          Text(pub.section,
                              style: const TextStyle(
                                  fontSize: 12, color: _kSubtext)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: _kSubtext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _kBorder),
              // Contenu scrollable — le modal reste fixe, seul le contenu défile
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Images (carousel)
                    Builder(builder: (_) {
                      final urls = pub.images.isNotEmpty
                          ? pub.images.map(_resolveImageUrl).where((u) => u.isNotEmpty).toList()
                          : (pub.image != null ? [_resolveImageUrl(pub.image)] : <String>[]);
                      final filtered = urls.where((u) => u.isNotEmpty).toList();
                      if (filtered.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          ImageCarousel(imageUrls: filtered),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                    // Statut
                    _modalRow(Icons.flag_outlined, 'Statut',
                        _isExpired(pub.dateLimite) ? 'Expirée' : 'Active',
                        valueColor: _isExpired(pub.dateLimite)
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A)),
                    if (pub.section.isNotEmpty)
                      _modalRow(Icons.layers_outlined, 'Section', pub.section),
                    if (pub.localite != null && pub.localite!.isNotEmpty)
                      _modalRow(Icons.location_on_outlined, 'Localité',
                          pub.localite!),
                    if (pub.niveau != null && pub.niveau!.isNotEmpty)
                      _modalRow(Icons.school_outlined, 'Niveau', pub.niveau!),
                    if (pub.domaine != null && pub.domaine!.isNotEmpty)
                      _modalRow(
                          Icons.category_outlined, 'Domaine', pub.domaine!),
                    if (pub.sexe != null && pub.sexe!.isNotEmpty)
                      _modalRow(Icons.wc_outlined, 'Sexe',
                          pub.sexe == 'M' ? 'Homme' : pub.sexe == 'F' ? 'Femme' : pub.sexe!),
                    if (pub.dateLimite != null && pub.dateLimite!.isNotEmpty)
                      _modalRow(Icons.calendar_today_outlined, 'Date limite',
                          _fmtDate(pub.dateLimite!)),
                    if (pub.createdAt != null && pub.createdAt!.isNotEmpty)
                      _modalRow(Icons.access_time_outlined, 'Publié le',
                          _fmtDate(pub.createdAt!)),
                    if (pub.contact.isNotEmpty)
                      _modalRow(
                          Icons.phone_outlined, 'Contact', pub.contact),
                    if (pub.telephonePostuler != null &&
                        pub.telephonePostuler!.isNotEmpty)
                      _modalRow(Icons.call_outlined, 'Téléphone postuler',
                          pub.telephonePostuler!),
                    if (pub.emailPostuler != null &&
                        pub.emailPostuler!.isNotEmpty)
                      _modalRow(Icons.email_outlined, 'Email postuler',
                          pub.emailPostuler!),
                    if (pub.whatsappPostuler != null &&
                        pub.whatsappPostuler!.isNotEmpty)
                      _modalRow(Icons.chat_outlined, 'WhatsApp',
                          pub.whatsappPostuler!),
                    if (pub.depotPhysiquePostuler != null &&
                        pub.depotPhysiquePostuler!.isNotEmpty)
                      _modalRow(Icons.place_outlined, 'Dépôt physique',
                          pub.depotPhysiquePostuler!),
                    if (pub.contenuTexte.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Description',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _kText)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Text(pub.contenuTexte,
                            style: const TextStyle(
                                fontSize: 14,
                                color: _kText,
                                height: 1.5)),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modalRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kPrimary),
          const SizedBox(width: 10),
          Text('$label : ',
              style: const TextStyle(fontSize: 13, color: _kSubtext)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _kText)),
          ),
        ],
      ),
    );
  }

  bool _isExpired(String? d) {
    if (d == null) return false;
    try { return DateTime.parse(d).isBefore(DateTime.now()); } catch (_) { return false; }
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }

  Widget _buildOffresTab() {
    final liste = _selectedTab == 0 ? _enCours : _historique;
    if (liste.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedTab == 0 ? Icons.work_outline : Icons.history,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 0 ? 'Aucune offre' : 'Aucun historique',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: liste.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final pub = liste[i];
        return _selectedTab == 0
            ? _OffreEnCoursCard(
                publication: pub,
                onTap: () => _showOffreModal(pub),
                onDelete: () => _delete(pub),
                onEdit: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CreatePublicationPage(publication: pub)),
                  );
                  _loadOffres(_user!);
                },
              )
            : _HistoriqueCard(
                publication: pub,
                onTap: () => _showOffreModal(pub),
                onDelete: () => _delete(pub),
                onRepublier: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreatePublicationPage()),
                  );
                  _loadOffres(_user!);
                },
              );
      },
    );
  }

  Widget _buildInfoTab() {
    final u = _user!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _sectionTitle('Informations de l\'entreprise',
            Icons.business_outlined, _kPrimary),
        const SizedBox(height: 10),
        _infoCard([
          _infoRow(Icons.business_outlined, 'Nom entreprise',
              u.nomEntreprise ?? '-'),
          _divider(),
          _infoRow(Icons.category_outlined, 'Secteur',
              u.secteurActivite ?? '-'),
          _divider(),
          _infoRow(Icons.email_outlined, 'Email', u.email),
          _divider(),
          _infoRow(Icons.phone_outlined, 'Téléphone', u.telephone),
          if (u.adresseEntreprise != null &&
              u.adresseEntreprise!.isNotEmpty) ...[
            _divider(),
            _infoRow(Icons.home_outlined, 'Adresse', u.adresseEntreprise!),
          ],
          if (u.localite != null && u.localite!.isNotEmpty) ...[
            _divider(),
            _infoRow(Icons.location_city_outlined, 'Localité', u.localite!),
          ],
          if (u.siteWeb != null && u.siteWeb!.isNotEmpty) ...[
            _divider(),
            _infoRow(Icons.language_outlined, 'Site web', u.siteWeb!),
          ],
        ]),
        const SizedBox(height: 20),
        if (u.descriptionEntreprise != null &&
            u.descriptionEntreprise!.isNotEmpty) ...[
          _sectionTitle(
              'À propos', Icons.info_outline, const Color(0xFF059669)),
          const SizedBox(height: 10),
          _infoCard([
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(u.descriptionEntreprise!,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF374151), height: 1.5)),
            ),
          ]),
          const SizedBox(height: 20),
        ],
        if (u.rccm != null || u.nif != null) ...[
          _sectionTitle('Informations légales', Icons.description_outlined,
              _kPrimary),
          const SizedBox(height: 10),
          _infoCard([
            if (u.rccm != null && u.rccm!.isNotEmpty)
              _infoRow(Icons.badge_outlined, 'RCCM', u.rccm!),
            if (u.rccm != null &&
                u.rccm!.isNotEmpty &&
                u.nif != null &&
                u.nif!.isNotEmpty)
              _divider(),
            if (u.nif != null && u.nif!.isNotEmpty)
              _infoRow(Icons.numbers_outlined, 'NIF', u.nif!),
          ]),
          const SizedBox(height: 20),
        ],

      ],
    );
  }

  Widget _badge(IconData icon, String label) => Container(
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

  Widget _sectionTitle(String title, IconData icon, Color color) => Row(
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
                  fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        ],
      );

  Widget _infoCard(List<Widget> children) => Container(
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

  Widget _divider() => const Divider(height: 1, indent: 56, color: _kBorder);

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: _kBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: _kPrimary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
            ),
          ],
        ),
      );
}

class _OffreEnCoursCard extends StatelessWidget {
  final Publication publication;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _OffreEnCoursCard(
      {required this.publication,
      required this.onTap,
      required this.onDelete,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Miniature image ou icône
          Builder(builder: (_) {
            final rawUrl = publication.images.isNotEmpty
                ? publication.images[0]
                : publication.image;
            final url = _resolveImageUrl(rawUrl);
            final fallback = Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.work_outline,
                  color: Color(0xFF1565C0), size: 22),
            );
            if (url.isEmpty) return fallback;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 52, height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            );
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                      publication.titre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1A1A2E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      publication.section,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                    if (publication.dateLimite != null &&
                        publication.dateLimite!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: Color(0xFFDC2626)),
                          const SizedBox(width: 3),
                          Text(
                            'Date limite : ${_fmt(publication.dateLimite!)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: const Color(0xFF1565C0),
                tooltip: 'Modifier',
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0).withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red,
                tooltip: 'Supprimer',
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
    ), // Container
    ); // GestureDetector
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _HistoriqueCard extends StatelessWidget {
  final Publication publication;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRepublier;

  const _HistoriqueCard(
      {required this.publication,
      required this.onTap,
      required this.onDelete,
      required this.onRepublier});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Miniature image ou icône historique
          Builder(builder: (_) {
            final rawUrl = publication.images.isNotEmpty
                ? publication.images[0]
                : publication.image;
            final url = _resolveImageUrl(rawUrl);
            final fallback = Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.history,
                  color: Colors.grey.shade500, size: 22),
            );
            if (url.isEmpty) return fallback;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 52, height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            );
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  publication.titre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1A2E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  publication.section,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                if (publication.dateLimite != null &&
                    publication.dateLimite!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 11, color: Color(0xFFDC2626)),
                      const SizedBox(width: 3),
                      Text(
                        'Date limite : ${_fmt(publication.dateLimite!)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRepublier,
            icon: const Icon(Icons.replay, size: 18),
            color: const Color(0xFF1565C0),
            tooltip: 'Republier',
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: const EdgeInsets.all(6),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0).withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red,
            tooltip: 'Supprimer',
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: const EdgeInsets.all(6),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    ), // Container
    ); // GestureDetector
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
