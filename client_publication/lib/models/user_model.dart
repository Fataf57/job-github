/// Classe pour représenter un domaine avec son niveau
class DomaineNiveau {
  String domaine;
  String? niveau;

  DomaineNiveau({
    required this.domaine,
    this.niveau,
  });

  factory DomaineNiveau.fromJson(Map<String, dynamic> json) {
    return DomaineNiveau(
      domaine: json['domaine'] ?? '',
      niveau: json['niveau'],
    );
  }

  Map<String, dynamic> toJson() => {
        'domaine': domaine,
        if (niveau != null && niveau!.isNotEmpty) 'niveau': niveau,
      };
}

class Utilisateur {
  int? id;
  String nom;
  String prenom;
  String email;
  String telephone;
  String motDePasse;
  String? photoProfil;
  String? role;
  bool? actif;
  // Champs chercheur d'emploi
  String? niveau;
  String? domaine;
  String? localite;
  String? sexe;
  // Champs recruteur / entreprise
  String? nomEntreprise;
  String? secteurActivite;
  String? descriptionEntreprise;
  String? adresseEntreprise;
  String? siteWeb;
  String? rccm;
  String? nif;
  String? logoEntreprise;

  // Liste des domaines avec leurs niveaux
  List<DomaineNiveau> _domainesNiveaux = [];

  // Getter pour obtenir la liste des domaines avec niveaux
  List<DomaineNiveau> get domainesNiveaux {
    return List.from(_domainesNiveaux);
  }

  // Getter pour obtenir la liste simple des noms de domaines (pour compatibilité)
  List<String> get domaines {
    return _domainesNiveaux.map((d) => d.domaine).toList();
  }

  // Setter pour définir la liste des domaines avec niveaux
  set domainesNiveaux(List<DomaineNiveau> domainesList) {
    _domainesNiveaux = List.from(domainesList);
  }

  // Setter pour définir la liste simple des domaines (pour compatibilité)
  set domaines(List<String> domainesList) {
    _domainesNiveaux = domainesList.map((d) => DomaineNiveau(domaine: d)).toList();
  }

  Utilisateur({
    this.id,
    this.nom = '',
    this.prenom = '',
    required this.email,
    required this.telephone,
    required this.motDePasse,
    this.photoProfil,
    this.role,
    this.actif,
    this.niveau,
    this.domaine,
    this.localite,
    this.sexe,
    this.nomEntreprise,
    this.secteurActivite,
    this.descriptionEntreprise,
    this.adresseEntreprise,
    this.siteWeb,
    this.rccm,
    this.nif,
    this.logoEntreprise,
  });

  bool get isRecruteur => role == 'RECRUTEUR';

  // Nom complet (nom + prénom)
  String get nomComplet => '$nom $prenom';

  // Factory constructor pour créer depuis JSON (backend)
  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    final user = Utilisateur(
      id: json['id'] != null ? (json['id'] is int ? json['id'] : int.tryParse(json['id'].toString())) : null,
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      email: json['email'] ?? '',
      telephone: json['telephone'] ?? '',
      motDePasse: json['motDePasse'] ?? '',
      photoProfil: json['photoProfil'],
      role: json['role'],
      actif: json['actif'] ?? true,
      niveau: json['niveau'],
      domaine: json['domaine'],
      localite: json['localite'],
      sexe: json['sexe'],
      nomEntreprise: json['nomEntreprise'],
      secteurActivite: json['secteurActivite'],
      descriptionEntreprise: json['descriptionEntreprise'],
      adresseEntreprise: json['adresseEntreprise'],
      siteWeb: json['siteWeb'],
      rccm: json['rccm'],
      nif: json['nif'],
      logoEntreprise: json['logoEntreprise'],
    );

    // Gérer les domaines avec niveaux
    if (json['domaines'] != null && json['domaines'] is List) {
      final domainesList = (json['domaines'] as List).map((item) {
        if (item is Map<String, dynamic>) {
          // Nouveau format: objet avec domaine et niveau
          return DomaineNiveau.fromJson(item);
        } else if (item is String) {
          // Ancien format: juste le nom du domaine
          return DomaineNiveau(domaine: item);
        }
        return DomaineNiveau(domaine: item.toString());
      }).toList();
      user._domainesNiveaux = domainesList;
    }

    return user;
  }

  Map<String, dynamic> toJson() => {
        if (id != null) "id": id,
        "nom": nom,
        "prenom": prenom,
        if (email.isNotEmpty) "email": email,
        "telephone": telephone,
        "motDePasse": motDePasse,
        if (photoProfil != null) "photoProfil": photoProfil,
        if (role != null) "role": role,
        if (actif != null) "actif": actif,
        if (niveau != null) "niveau": niveau,
        "domaines": _domainesNiveaux.map((d) => d.toJson()).toList(),
        if (localite != null) "localite": localite,
        if (sexe != null) "sexe": sexe,
        // Champs recruteur
        if (nomEntreprise != null) "nomEntreprise": nomEntreprise,
        if (secteurActivite != null) "secteurActivite": secteurActivite,
        if (descriptionEntreprise != null) "descriptionEntreprise": descriptionEntreprise,
        if (adresseEntreprise != null) "adresseEntreprise": adresseEntreprise,
        if (siteWeb != null) "siteWeb": siteWeb,
        if (rccm != null) "rccm": rccm,
        if (nif != null) "nif": nif,
        if (logoEntreprise != null) "logoEntreprise": logoEntreprise,
      };

  // Créer une copie de l'utilisateur avec des modifications
  Utilisateur copyWith({
    int? id,
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    String? motDePasse,
    String? photoProfil,
    String? role,
    bool? actif,
    String? niveau,
    String? domaine,
    String? localite,
    String? sexe,
  }) {
    return Utilisateur(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      motDePasse: motDePasse ?? this.motDePasse,
      photoProfil: photoProfil ?? this.photoProfil,
      role: role ?? this.role,
      actif: actif ?? this.actif,
      niveau: niveau ?? this.niveau,
      domaine: domaine ?? this.domaine,
      localite: localite ?? this.localite,
      sexe: sexe ?? this.sexe,
    );
  }
}
