import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/publication.dart';
import '../services/publication_service.dart';
import '../services/auth_service.dart';
import '../utils/file_url.dart';
import '../widgets/image_carousel.dart';
import '../widgets/pdf_preview.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'create_publication_page.dart';
import 'pdf_viewer_page.dart';
import 'settings_page.dart';

class PublicationPage extends StatefulWidget {
  final bool showBackButton;

  const PublicationPage({super.key, this.showBackButton = false});

  @override
  State<PublicationPage> createState() => _PublicationPageState();
}

class _PublicationPageState extends State<PublicationPage> {
  final PublicationService _service = PublicationService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();

  // État des publications (pagination)
  List<Publication> _publications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _loadError;

  // Section sélectionnée par défaut (sera initialisée après chargement)
  String? _selectedSection;
  // Localité sélectionnée (null = toutes les localités)
  String? _selectedLocalite;
  String _userName = "Invité";
  String? _userPhoto;
  int? _userId; // ID utilisateur — paramètre API (filtrage côté serveur)
  bool _isLoggedIn = false;
  bool _isRecruteur = false;
  
  // Liste des localités disponibles (chargée depuis le backend)
  List<String> _localites = [];
  // Liste des sections disponibles (chargée depuis le backend)
  List<String> _sections = [];
  // Map pour suivre l'état des favoris (publication_id -> is_favori)
  Map<int, bool> _favorisStatus = {};
  // Indique si on affiche les favoris
  bool _showFavoris = false;
  // Dernière fois que l'utilisateur a visité chaque section (clé = nom section)
  Map<String, DateTime> _lastVisitedPerSection = {};
  // Nombre de publications non vues par section (clé = nom section)
  Map<String, int> _unseenCountPerSection = {};
  // Nombre de publications non vues par localité (clé = localité en majuscule)
  Map<String, int> _unseenCountPerLocalite = {};
  // Cache de toutes les publications (toutes sections) pour calcul des badges
  List<Publication> _allPublications = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadReferenceLists().then((_) {
      _loadLastVisitedTimestamps().then((_) {
        _initializeData();
        _fetchAllPublicationsForBadges();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMorePublications();
    }
  }

  Future<void> _loadReferenceLists() async {
    try {
      final referenceLists = await _service.fetchReferenceLists();
      if (!mounted) return;
      final sections = referenceLists.sections.isNotEmpty
          ? referenceLists.sections
          : ['Professionnelle', 'Locale'];
      setState(() {
        _localites = referenceLists.localites;
        _sections = sections;
        if (_selectedSection == null && _sections.isNotEmpty) {
          _selectedSection = _sections.first;
        }
      });
      print('✅ Sections chargées: ${_sections.length} — $_sections');
      if (referenceLists.sections.isEmpty) {
        print('⚠️ Sections vides côté API — repli local Professionnelle / Locale');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des listes de référence: $e');
      if (!mounted) return;
      setState(() {
        _localites = ['OUAGA', 'BOBO', 'KOUDOU'];
        _sections = ['Professionnelle', 'Locale'];
        if (_selectedSection == null) {
          _selectedSection = _sections.first;
        }
      });
    }
  }

  Future<void> _initializeData() async {
    await _loadUserInfo();
    // Marquer la section initiale comme visitée dès l'ouverture
    if (_selectedSection != null) {
      await _markSectionVisited(_selectedSection!);
    }
    _loadPublications();
  }

  Future<void> _loadUserInfo() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      final user = await _authService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _isLoggedIn = true;
          _isRecruteur = user.isRecruteur;
          _userName = user.isRecruteur
              ? (user.nomEntreprise ?? user.email)
              : user.nomComplet;
          _userPhoto = user.photoProfil;
          _userId = user.id;
        });
      }
    }
  }

  void _loadPublications() {
    setState(() {
      _publications = [];
      _currentPage = 1;
      _hasMore = true;
      _loadError = null;
      _isLoading = true;
    });
    _fetchPage(1, reset: true);
  }

  Future<void> _fetchPage(int page, {bool reset = false}) async {
    // --- Favoris (pas de pagination côté serveur pour les favoris) ---
    if (_showFavoris) {
      if (_userId == null) {
        setState(() { _publications = []; _isLoading = false; _hasMore = false; });
        return;
      }
      try {
        final all = await _service.getFavoris(
          _userId!,
          localite: _selectedLocalite,
        );
        _loadFavorisStatus(all);
        if (mounted) {
          setState(() {
            _publications = all;
            _isLoading = false;
            _isLoadingMore = false;
            _hasMore = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() { _loadError = e.toString(); _isLoading = false; _isLoadingMore = false; });
      }
      return;
    }

    // --- Aucune section disponible ---
    if (_sections.isEmpty || _selectedSection == null) {
      setState(() { _publications = []; _isLoading = false; _hasMore = false; });
      return;
    }

    try {
      List<Publication> newPubs;
      bool hasNext;

      if (_selectedLocalite != null && _selectedLocalite!.isNotEmpty) {
        // Toutes sections : filtrage localité côté serveur via /tout
        final result = await _service.fetchPublications(
          utilisateurId: _userId,
          localite: _selectedLocalite,
          page: page,
        );
        newPubs = result.results;
        hasNext = result.hasNext;
      } else {
        final result = await _service.fetchBySection(
          _selectedSection!,
          utilisateurId: _userId,
          page: page,
        );
        newPubs = result.results;
        hasNext = result.hasNext;
      }

      _loadFavorisStatus(newPubs);

      if (mounted) {
        setState(() {
          if (reset) {
            _publications = newPubs;
          } else {
            _publications = [..._publications, ...newPubs];
          }
          _currentPage = page;
          _hasMore = hasNext;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('❌ Erreur lors du chargement page $page: $e');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMorePublications() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    setState(() { _isLoadingMore = true; });
    await _fetchPage(_currentPage + 1, reset: false);
  }

  /// Charger les timestamps de dernière visite par section depuis SharedPreferences
  Future<void> _loadLastVisitedTimestamps() async {
    if (_sections.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final Map<String, DateTime> timestamps = {};
    for (final section in _sections) {
      final stored = prefs.getString('last_visited_$section');
      if (stored != null) {
        try {
          timestamps[section] = DateTime.parse(stored);
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _lastVisitedPerSection = timestamps;
      });
    }
  }

  /// Marquer une section comme visitée maintenant et sauvegarder
  Future<void> _markSectionVisited(String section) async {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _lastVisitedPerSection[section] = now;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_visited_$section', now.toIso8601String());
    _computeUnseenCounts();
  }

  /// Calculer le nombre de publications non vues par section et par localité
  /// Une publication est "non vue" si elle est plus récente que la dernière visite
  /// (ou si la section n'a jamais été visitée)
  void _computeUnseenCounts() {
    if (!mounted) return;
    final Map<String, int> perSection = {};
    final Map<String, int> perLocalite = {};

    for (final pub in _allPublications) {
      if (pub.createdAt == null) continue;
      DateTime pubDate;
      try {
        pubDate = DateTime.parse(pub.createdAt!);
      } catch (_) {
        continue;
      }

      final sec = pub.section.trim();
      final lastVisited = _lastVisitedPerSection[sec];

      // Non vu si : section jamais visitée OU publication plus récente que dernière visite
      final isUnseen = lastVisited == null || pubDate.isAfter(lastVisited);

      if (isUnseen) {
        if (sec.isNotEmpty) {
          perSection[sec] = (perSection[sec] ?? 0) + 1;
        }
        if (pub.localite != null && pub.localite!.trim().isNotEmpty) {
          final loc = pub.localite!.trim().toUpperCase();
          perLocalite[loc] = (perLocalite[loc] ?? 0) + 1;
        }
      }
    }

    setState(() {
      _unseenCountPerSection = perSection;
      _unseenCountPerLocalite = perLocalite;
    });
  }

  /// Charger toutes les publications de toutes les sections en arrière-plan
  /// pour calculer les badges sur chaque onglet
  Future<void> _fetchAllPublicationsForBadges() async {
    if (_sections.isEmpty) return;
    try {
      final futures = _sections.map(
        (section) => _service.fetchBySection(
          section,
          utilisateurId: _userId,
          page: 1,
        ),
      ).toList();
      final results = await Future.wait(futures);
      final all = <Publication>[];
      final dedupeIds = <int>{};
      for (final paginated in results) {
        for (final pub in paginated.results) {
          if (pub.id != null && dedupeIds.add(pub.id!)) {
            all.add(pub);
          }
        }
      }
      if (mounted) {
        setState(() { _allPublications = all; });
        _computeUnseenCounts();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des badges: $e');
    }
  }

  /// Charger l'état des favoris pour une liste de publications
  Future<void> _loadFavorisStatus(List<Publication> publications) async {
    if (_userId == null) return;
    
    for (var pub in publications) {
      if (pub.id != null && !_favorisStatus.containsKey(pub.id)) {
        try {
          final isFavori = await _service.checkFavori(pub.id!, _userId!);
          setState(() {
            _favorisStatus[pub.id!] = isFavori;
          });
        } catch (e) {
          print('❌ Erreur lors de la vérification du favori pour la publication ${pub.id}: $e');
        }
      }
    }
  }

  /// Toggle favori pour une publication
  Future<void> _toggleFavori(Publication publication) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour ajouter aux favoris'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (publication.id == null) return;

    final currentStatus = _favorisStatus[publication.id!] ?? false;
    
    setState(() {
      // Mise à jour optimiste de l'UI
      _favorisStatus[publication.id!] = !currentStatus;
    });

    try {
      bool newStatus;
      if (currentStatus) {
        newStatus = await _service.removeFavori(publication.id!, _userId!);
      } else {
        newStatus = await _service.addFavori(publication.id!, _userId!);
      }
      
      setState(() {
        _favorisStatus[publication.id!] = newStatus;
      });

      if (_showFavoris && !newStatus) {
        // Si on est dans la section favoris et qu'on retire un favori, recharger
        _loadPublications();
      }
    } catch (e) {
      // En cas d'erreur, restaurer l'état précédent
      setState(() {
        _favorisStatus[publication.id!] = currentStatus;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterBySection(String section) {
    if (section == 'Favoris') {
      setState(() {
        _showFavoris = true;
        _selectedSection = null;
      });
    } else {
      setState(() {
        _showFavoris = false;
        _selectedSection = section;
      });
      // Marquer la section comme visitée maintenant → badge reset à 0
      _markSectionVisited(section);
    }
    _loadPublications();
  }

  void _filterByLocalite(String? localite) {
    setState(() {
      _selectedLocalite = localite;
      _loadPublications();
    });
  }

  // Fonction pour construire l'URL complète
  String _buildFileUrl(String? filePath) => buildPublicationFileUrl(filePath);

  // Fonction pour calculer "il y a ..."
  String _getTimeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return "À l'instant";
      } else if (difference.inHours < 1) {
        return "Il y a ${difference.inMinutes} min";
      } else if (difference.inHours < 24) {
        return "Il y a ${difference.inHours} h";
      } else if (difference.inDays < 7) {
        return "Il y a ${difference.inDays} j";
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return "Il y a $weeks sem";
      } else {
        final months = (difference.inDays / 30).floor();
        return "Il y a $months mois";
      }
    } catch (e) {
      return dateString.split('T').first;
    }
  }

  // Fonction pour formater la date limite en format jj/mm/année
  String _formatDateLimiteSimple(String? dateLimiteStr) {
    if (dateLimiteStr == null || dateLimiteStr.isEmpty) {
      return '';
    }
    
    try {
      final dateLimite = DateTime.parse(dateLimiteStr);
      final day = dateLimite.day.toString().padLeft(2, '0');
      final month = dateLimite.month.toString().padLeft(2, '0');
      final year = dateLimite.year.toString();
      return '$day/$month/$year';
    } catch (e) {
      return dateLimiteStr;
    }
  }

  // Fonction pour vérifier si la date limite est expirée
  bool _isDateLimiteExpired(String? dateLimiteStr) {
    if (dateLimiteStr == null || dateLimiteStr.isEmpty) {
      return false;
    }
    
    try {
      final dateLimite = DateTime.parse(dateLimiteStr);
      return dateLimite.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // Fonction pour détecter si c'est un lien
  bool _isLink(String text) {
    return text.startsWith('http://') || 
           text.startsWith('https://') ||
           text.startsWith('www.') ||
           text.contains('.com') ||
           text.contains('.org') ||
           text.contains('.net');
  }

  // Fonction pour créer un badge d'information
  Widget _buildInfoBadge(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color[700],
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Fonction pour créer un bouton de contact
  Widget _buildContactButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug: afficher l'état des sections
    print('🔍 Build - Sections disponibles: ${_sections.length}, Sections: $_sections');
    print('🔍 Build - Section sélectionnée: $_selectedSection');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 110,
        leading: Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Paramètres',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Rechercher',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recherche à venir')),
                  );
                },
              ),
            ],
          ),
        ),
        title: const Text(
          'FASO JOB',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final totalUnseen = _unseenCountPerSection.values
                        .fold(0, (sum, c) => sum + c);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded),
                          tooltip: 'Notifications',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Notifications à venir')),
                            );
                          },
                        ),
                        if (totalUnseen > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  totalUnseen > 99 ? '99+' : '$totalUnseen',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    if (_isLoggedIn && _isRecruteur) {
                      // Recruteur : retour au tableau de bord
                      Navigator.pop(context);
                    } else if (_isLoggedIn) {
                      final _ = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                      if (mounted) _loadUserInfo();
                    } else {
                      final _ = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                      if (mounted) _loadUserInfo();
                    }
                  },
                  child: CircleAvatar(
                    backgroundImage: _userPhoto != null && _userPhoto!.isNotEmpty
                        ? NetworkImage(_userPhoto!)
                        : null,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    radius: 17,
                    child: _userPhoto == null || _userPhoto!.isEmpty
                        ? Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'I',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // Filtres localités
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: Row(
                children: _localites.map((localite) {
                  final isSelected = _selectedLocalite == localite;
                  final unseenLoc = _unseenCountPerLocalite[localite.toUpperCase()] ?? 0;
                  return GestureDetector(
                    onTap: () => isSelected
                        ? _filterByLocalite(null)
                        : _filterByLocalite(localite),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1565C0)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1565C0)
                                          .withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.location_on,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                localite,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unseenLoc > 0 && !isSelected)
                          Positioned(
                            right: 4,
                            top: -4,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unseenLoc > 99 ? '99+' : '$unseenLoc',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ),

          // Liste des publications
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadUserInfo();
                _loadPublications();
                // Attendre un peu pour que le refresh soit visible
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: _isLoading
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF1565C0)),
                              SizedBox(height: 16),
                              Text(
                                "Chargement des publications...",
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : _loadError != null && _publications.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height - 200,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.wifi_off_rounded,
                                          size: 48, color: Color(0xFFDC2626)),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "Erreur de connexion",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _loadError ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _loadPublications,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text("Réessayer"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1565C0),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : _publications.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height - 200,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          "Aucune publication disponible",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _selectedLocalite != null && _selectedLocalite!.isNotEmpty
                                              ? "Aucune publication pour la localité \"$_selectedLocalite\""
                                              : _selectedSection != null
                                                  ? "Aucune publication dans la section \"$_selectedSection\""
                                                  : "Aucune publication disponible",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                              itemCount: _publications.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Indicateur de chargement en bas de liste
                                if (index == _publications.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                                    ),
                                  );
                                }
                                final pub = _publications[index];
                final imageUrls = pub.images.map(_buildFileUrl).where((u) => u.isNotEmpty).toList();
                final imageUrl = imageUrls.isNotEmpty ? imageUrls.first : _buildFileUrl(pub.image);
                final pdfUrl = _buildFileUrl(pub.pdf);
                final profileImageUrl = _buildFileUrl(pub.auteur.photoProfil);
                final hasImage = imageUrls.isNotEmpty;
                final hasPdf = pdfUrl.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ En-tête avec Auteur et bouton favori
                        Row(
                          children: [
                            // Photo de profil
                            CircleAvatar(
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? NetworkImage(profileImageUrl)
                                  : const AssetImage('assets/images/profil.jpg')
                                      as ImageProvider,
                              radius: 22,
                              backgroundColor: Colors.grey[200],
                            ),
                            const SizedBox(width: 12),
                            // Nom et date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pub.auteur.nom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getTimeAgo(pub.createdAt ?? ''),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Badge expiré (offres enregistrées)
                            if (_showFavoris &&
                                pub.dateLimite != null &&
                                DateTime.tryParse(pub.dateLimite!)
                                        ?.isBefore(DateTime.now()) ==
                                    true)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade300),
                                ),
                                child: Text('Expiré',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600)),
                              ),
                            // Bouton enregistrer
                            if (_isLoggedIn && pub.id != null)
                              IconButton(
                                icon: Icon(
                                  _favorisStatus[pub.id!] == true
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  color: _favorisStatus[pub.id!] == true
                                      ? const Color(0xFF1565C0)
                                      : Colors.grey[600],
                                ),
                                onPressed: () => _toggleFavori(pub),
                                tooltip: _favorisStatus[pub.id!] == true
                                    ? 'Retirer'
                                    : 'Enregistrer',
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ✅ Titre - Rendu plus visible et important
                        Text(
                          pub.titre,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                            color: Colors.black87,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // ✅ IMAGES (carousel si plusieurs)
                        if (hasImage)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildPublicationImageSection(
                              context: context,
                              imageUrls: imageUrls,
                              titre: pub.titre,
                              description: pub.contenuTexte,
                            ),
                          ),

                        // Description affichée seulement sans image
                        if (!hasImage && pub.contenuTexte.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                pub.contenuTexte,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ),

                        // ✅ PDF
                        if (hasPdf)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GestureDetector(
                              onTap: () => _openPdf(context, pdfUrl, titre: pub.titre),
                              child: PdfPreviewCard(pdfUrl: pdfUrl),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // ✅ Section "Moyens de postuler" (affichée seulement s'il y a au moins un moyen)
                        if ((pub.telephonePostuler != null && pub.telephonePostuler!.isNotEmpty) ||
                            (pub.emailPostuler != null && pub.emailPostuler!.isNotEmpty) ||
                            (pub.whatsappPostuler != null && pub.whatsappPostuler!.isNotEmpty) ||
                            (pub.depotPhysiquePostuler != null && pub.depotPhysiquePostuler!.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Liste des moyens de contact (alignés verticalement)
                                Column(
                                  children: [
                                  // Téléphone pour postuler
                                  if (pub.telephonePostuler != null && pub.telephonePostuler!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: _buildContactButton(
                                        context: context,
                                        icon: Icons.phone,
                                        label: 'Contacter le :',
                                        value: pub.telephonePostuler!,
                                        color: Colors.blueAccent,
                                        onTap: () => _contactNumber(context, pub.telephonePostuler!),
                                      ),
                                    ),
                                  
                                  // Email pour postuler
                                  if (pub.emailPostuler != null && pub.emailPostuler!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: _buildContactButton(
                                        context: context,
                                        icon: Icons.email,
                                        label: 'Réception de document sur mail :',
                                        value: pub.emailPostuler!,
                                        color: Colors.blueAccent,
                                        onTap: () => _openLink(context, 'mailto:${pub.emailPostuler!}'),
                                      ),
                                    ),
                                  
                                  // WhatsApp pour postuler
                                  if (pub.whatsappPostuler != null && pub.whatsappPostuler!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: _buildContactButton(
                                        context: context,
                                        icon: Icons.chat,
                                        label: 'Réception sur WhatsApp :',
                                        value: pub.whatsappPostuler!,
                                        color: Colors.blueAccent,
                                        onTap: () => _openLink(context, pub.whatsappPostuler!),
                                      ),
                                    ),
                                  
                                  // Dépôt physique pour postuler
                                  if (pub.depotPhysiquePostuler != null && pub.depotPhysiquePostuler!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: _buildContactButton(
                                        context: context,
                                        icon: Icons.location_on,
                                        label: 'Dépôt physique :',
                                        value: pub.depotPhysiquePostuler!,
                                        color: Colors.blueAccent,
                                        onTap: () {},
                                      ),
                                    ),
                                ],
                              ),
                              
                              // Date limite en dessous
                              if (pub.dateLimite != null && pub.dateLimite!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Date limite :',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDateLimiteSimple(pub.dateLimite),
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      ),

      // Barre de navigation inférieure (sections + Favoris)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
          ),
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ..._sections.asMap().entries.map((entry) {
                  final i = entry.key;
                  final section = entry.value;
                  final isActive = !_showFavoris && _selectedSection == section;
                  final icons = [
                    Icons.business_center_outlined,
                    Icons.location_city_outlined,
                    Icons.category_outlined,
                  ];
                  final iconsActive = [
                    Icons.business_center,
                    Icons.location_city,
                    Icons.category,
                  ];
                  final icon = i < icons.length ? icons[i] : Icons.category_outlined;
                  final iconActive =
                      i < iconsActive.length ? iconsActive[i] : Icons.category;
                  final unseenSection = _unseenCountPerSection[section] ?? 0;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _filterBySection(section),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF1565C0).withOpacity(0.16)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF1565C0).withOpacity(0.4)
                                : const Color(0xFFD1D5DB),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  isActive ? iconActive : icon,
                                  color: isActive
                                      ? const Color(0xFF1565C0)
                                      : const Color(0xFF4B5563),
                                  size: 21,
                                ),
                                if (unseenSection > 0 && !isActive)
                                  Positioned(
                                    right: -6,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unseenSection > 99 ? '99+' : '$unseenSection',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              section,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isActive
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF4B5563),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                // Favoris
                Expanded(
                  child: GestureDetector(
                    onTap: () => _filterBySection('Favoris'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _showFavoris
                            ? const Color(0xFF1565C0).withOpacity(0.14)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showFavoris
                              ? const Color(0xFF1565C0).withOpacity(0.35)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showFavoris
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: _showFavoris
                                ? const Color(0xFF1565C0)
                                : const Color(0xFF4B5563),
                            size: 21,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enregistrer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _showFavoris
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _showFavoris
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Bouton flottant pour créer une publication (recruteurs uniquement)
      floatingActionButton: _isLoggedIn && _isRecruteur
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePublicationPage(),
                  ),
                );
                if (result == true && mounted) _loadPublications();
              },
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 4,
              label: const Text('+',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              tooltip: 'Créer une publication',
            )
          : null,
    );
  }

  // Fonction pour afficher les détails
  void _showPublicationDetails(BuildContext context, Publication publication) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Auteur dans les détails
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: _buildFileUrl(publication.auteur.photoProfil).isNotEmpty
                          ? NetworkImage(_buildFileUrl(publication.auteur.photoProfil))
                          : const AssetImage('assets/images/profil.jpg') as ImageProvider,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publication.auteur.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _getTimeAgo(publication.createdAt ?? ''),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ✅ Titre amélioré dans les détails
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blue[200]!,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    publication.titre,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: Colors.blue[900],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ✅ Date limite avec label dans les détails
                if (publication.dateLimite != null && publication.dateLimite!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date limite :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDateLimiteSimple(publication.dateLimite),
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ✅ Moyens de postuler dans les détails (aligné sur la carte : pas de champs « liens » séparés)
                if ((publication.telephonePostuler != null && publication.telephonePostuler!.isNotEmpty) ||
                    (publication.emailPostuler != null && publication.emailPostuler!.isNotEmpty) ||
                    (publication.whatsappPostuler != null && publication.whatsappPostuler!.isNotEmpty) ||
                    (publication.depotPhysiquePostuler != null && publication.depotPhysiquePostuler!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moyens de postuler :',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            // Téléphone pour postuler
                            if (publication.telephonePostuler != null && publication.telephonePostuler!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: () => _contactNumber(context, publication.telephonePostuler!),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blueAccent.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.phone, color: Colors.blueAccent, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Contacter le :',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                publication.telephonePostuler!,
                                                style: TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Email pour postuler
                            if (publication.emailPostuler != null && publication.emailPostuler!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: () => _openLink(context, 'mailto:${publication.emailPostuler!}'),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blueAccent.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.email, color: Colors.blueAccent, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Réception de document sur mail :',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                publication.emailPostuler!,
                                                style: TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            
                            // WhatsApp pour postuler
                            if (publication.whatsappPostuler != null && publication.whatsappPostuler!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: InkWell(
                                  onTap: () => _openLink(context, publication.whatsappPostuler!),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blueAccent.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat, color: Colors.blueAccent, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Réception sur WhatsApp :',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                publication.whatsappPostuler!,
                                                style: TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Dépôt physique pour postuler
                            if (publication.depotPhysiquePostuler != null && publication.depotPhysiquePostuler!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.blueAccent, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Dépôt physique :',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              publication.depotPhysiquePostuler!,
                                              style: TextStyle(
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),

                // Affichage des images dans les détails
                if (publication.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildPublicationImageSection(
                      context: context,
                      imageUrls: publication.images
                          .map(_buildFileUrl)
                          .where((u) => u.isNotEmpty)
                          .toList(),
                      titre: publication.titre,
                      description: publication.contenuTexte,
                    ),
                  )
                else if (publication.image != null && publication.image!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildPublicationImageSection(
                      context: context,
                      imageUrls: [_buildFileUrl(publication.image)],
                      titre: publication.titre,
                      description: publication.contenuTexte,
                    ),
                  ),

                // Affichage du PDF dans les détails
                if (publication.pdf != null && publication.pdf!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () => _openPdf(
                          context,
                          _buildFileUrl(publication.pdf),
                          titre: publication.titre),
                      child: PdfPreviewCard(
                        pdfUrl: _buildFileUrl(publication.pdf),
                      ),
                    ),
                  ),

                if (publication.images.isEmpty &&
                    (publication.image == null || publication.image!.isEmpty) &&
                    publication.contenuTexte.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    publication.contenuTexte,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Fonction pour postuler
  void _showApplyDialog(BuildContext context, Publication publication) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Postuler"),
        content: Text("Voulez-vous postuler à \"${publication.titre}\" ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Candidature envoyée pour \"${publication.titre}\""),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Postuler"),
          ),
        ],
      ),
    );
  }

  // Fonction pour ouvrir un lien
  void _openLink(BuildContext context, String link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ouvrir le lien"),
        content: Text("Voulez-vous ouvrir : $link ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Ouverture du lien : $link"),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text("Ouvrir"),
          ),
        ],
      ),
    );
  }

  // Fonction pour contacter un numéro
  void _contactNumber(BuildContext context, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contacter"),
        content: Text("Voulez-vous appeler : $number ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Appel vers : $number"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Appeler"),
          ),
        ],
      ),
    );
  }


  Widget _buildPublicationImageSection({
    required BuildContext context,
    required List<String> imageUrls,
    required String titre,
    required String description,
  }) {
    final hasDescription = description.trim().isNotEmpty;

    return Stack(
      children: [
        ImageCarousel(imageUrls: imageUrls),
        if (hasDescription)
          Positioned(
            left: 10,
            bottom: 10,
            child: Material(
              color: Colors.black54,
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _showPublicationDescription(context, titre, description),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showPublicationDescription(
    BuildContext context,
    String titre,
    String description,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Fonction pour ouvrir le PDF
  void _openPdf(BuildContext context, String pdfUrl, {String titre = "Document PDF"}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerPage(
          pdfUrl: pdfUrl,
          titre: titre,
        ),
      ),
    );
  }
}