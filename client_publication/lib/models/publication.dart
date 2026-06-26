// models/publication.dart
class Publication {
  final int? id;
  final String titre;
  final String contenuTexte;
  final String? image; // Image principale (rétrocompatibilité)
  final List<String> images; // Liste de toutes les images
  final String? pdf; // ✅ PDF optionnel
  final String contact;
  final String? lienEmail; // Lien email
  final String? lienSiteWeb; // Lien site web
  final String? lienWhatsapp; // Lien WhatsApp
  final String? telephonePostuler; // Téléphone pour postuler
  final String? emailPostuler; // Email pour postuler
  final String? whatsappPostuler; // WhatsApp pour postuler
  final String? depotPhysiquePostuler; // Dépôt physique pour postuler
  final String? createdAt; // ✅ Date de création depuis createdAt
  final String? dateLimite; // ✅ Date limite pour la publication
  final String section;
  final String? niveau;
  final String? domaine; // Chaîne séparée par des virgules pour le backend
  final String? localite;
  final String? sexe;
  final Utilisateur auteur;

  // Getter pour obtenir la liste des domaines
  List<String> get domaines {
    if (domaine == null || domaine!.trim().isEmpty) {
      return [];
    }
    try {
      return domaine!.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Publication({
    this.id,
    required this.titre,
    required this.contenuTexte,
    this.image,
    this.images = const [],
    this.pdf,
    required this.contact,
    this.lienEmail,
    this.lienSiteWeb,
    this.lienWhatsapp,
    this.telephonePostuler,
    this.emailPostuler,
    this.whatsappPostuler,
    this.depotPhysiquePostuler,
    this.createdAt,
    this.dateLimite,
    required this.section,
    this.niveau,
    this.domaine,
    this.localite,
    this.sexe,
    required this.auteur,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    try {
      // Convertir createdAt (LocalDateTime) en String
      String? createdAtStr;
      if (json['createdAt'] != null) {
        if (json['createdAt'] is String) {
          createdAtStr = json['createdAt'];
        } else if (json['createdAt'] is Map) {
          // Si c'est un objet LocalDateTime, essayer d'extraire
          final dateMap = json['createdAt'] as Map;
          if (dateMap.containsKey('year') && dateMap.containsKey('month') && dateMap.containsKey('dayOfMonth')) {
            createdAtStr = '${dateMap['year']}-${dateMap['month']}-${dateMap['dayOfMonth']}';
          } else {
            createdAtStr = json['createdAt'].toString();
          }
        } else {
          createdAtStr = json['createdAt'].toString();
        }
      }

      // Convertir dateLimite (LocalDateTime) en String
      String? dateLimiteStr;
      if (json['dateLimite'] != null) {
        if (json['dateLimite'] is String) {
          dateLimiteStr = json['dateLimite'];
        } else if (json['dateLimite'] is Map) {
          final dateMap = json['dateLimite'] as Map;
          if (dateMap.containsKey('year') && dateMap.containsKey('month') && dateMap.containsKey('dayOfMonth')) {
            dateLimiteStr = '${dateMap['year']}-${dateMap['month']}-${dateMap['dayOfMonth']}';
          } else {
            dateLimiteStr = json['dateLimite'].toString();
          }
        } else {
          dateLimiteStr = json['dateLimite'].toString();
        }
      }

      // Gérer l'auteur - peut être un objet ou null
      Utilisateur auteur;
      if (json['auteur'] != null && json['auteur'] is Map) {
        try {
          auteur = Utilisateur.fromJson(json['auteur'] as Map<String, dynamic>);
        } catch (e) {
          print('⚠️ Erreur lors du parsing de l\'auteur: $e');
          // Créer un utilisateur par défaut si le parsing échoue
          final auteurMap = json['auteur'] as Map?;
          String nomAuteur = 'Auteur inconnu';
          if (auteurMap != null) {
            final nomComplet = auteurMap['nomComplet']?.toString();
            final nom = auteurMap['nom']?.toString();
            if (nomComplet != null && nomComplet.isNotEmpty) {
              nomAuteur = nomComplet;
            } else if (nom != null && nom.isNotEmpty) {
              nomAuteur = nom;
            }
          }
          // Parser l'ID de manière sécurisée
          int? auteurId;
          if (auteurMap != null) {
            final idValue = auteurMap['id'];
            if (idValue is int) {
              auteurId = idValue;
            } else if (idValue != null) {
              auteurId = int.tryParse(idValue.toString());
            }
          }
          
          auteur = Utilisateur(
            id: auteurId,
            nom: nomAuteur,
            photoProfil: auteurMap?['photoProfil']?.toString(),
          );
        }
      } else {
        // Si auteur est null ou n'est pas un Map, créer un utilisateur par défaut
        auteur = Utilisateur(nom: 'Auteur inconnu');
      }

      // Gérer les domaines (peut être une liste ou une chaîne)
      String? domaineValue;
      if (json['domaines'] != null && json['domaines'] is List) {
        // Si c'est une liste, la convertir en chaîne
        final domainesList = (json['domaines'] as List).map((e) => e.toString()).toList();
        domaineValue = domainesList.isEmpty ? null : domainesList.join(', ');
      } else if (json['domaine'] != null) {
        // Si c'est une chaîne, l'utiliser directement
        domaineValue = json['domaine']?.toString();
      }

      // Parser la liste d'images
      List<String> imagesList = [];
      if (json['images'] != null && json['images'] is List) {
        imagesList = (json['images'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      // Fallback : si aucune image dans la liste, utiliser l'image principale
      if (imagesList.isEmpty && json['image'] != null && json['image'].toString().isNotEmpty) {
        imagesList = [json['image'].toString()];
      }

      return Publication(
        id: json['id'] is int ? json['id'] : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
        titre: (json['titre']?.toString() ?? '').trim(),
        contenuTexte: (json['contenuTexte']?.toString() ?? '').trim(), // Peut être vide maintenant
        image: json['image']?.toString(),
        images: imagesList,
        pdf: json['pdf']?.toString(),
        contact: (json['contact']?.toString() ?? '').trim(),
        lienEmail: json['lienEmail']?.toString(),
        lienSiteWeb: json['lienSiteWeb']?.toString(),
        lienWhatsapp: json['lienWhatsapp']?.toString(),
        telephonePostuler: json['telephonePostuler']?.toString(),
        emailPostuler: json['emailPostuler']?.toString(),
        whatsappPostuler: json['whatsappPostuler']?.toString(),
        depotPhysiquePostuler: json['depotPhysiquePostuler']?.toString(),
        createdAt: createdAtStr,
        dateLimite: dateLimiteStr,
        section: (json['section']?.toString() ?? '').trim(),
        niveau: json['niveau']?.toString(),
        domaine: domaineValue,
        localite: json['localite']?.toString(),
        sexe: json['sexe']?.toString(),
        auteur: auteur,
      );
    } catch (e) {
      print('❌ Erreur lors du parsing de Publication: $e');
      print('📋 JSON reçu: $json');
      rethrow;
    }
  }
}

class Utilisateur {
  final int? id;
  final String nom;
  final String? photoProfil;

  Utilisateur({
    this.id,
    required this.nom,
    this.photoProfil,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    try {
      // Django retourne 'nom' et 'prenom' séparément
      String nomValue = 'Utilisateur inconnu'; // Valeur par défaut
      
      if (json['nomComplet'] != null) {
        final nomComplet = json['nomComplet'];
        nomValue = (nomComplet?.toString() ?? '').trim();
        if (nomValue.isEmpty) {
          nomValue = 'Utilisateur inconnu';
        }
      } else if (json['nom'] != null || json['prenom'] != null) {
        // Django: combiner nom et prenom
        final nom = (json['nom']?.toString() ?? '').trim();
        final prenom = (json['prenom']?.toString() ?? '').trim();
        nomValue = '$prenom $nom'.trim();
        if (nomValue.isEmpty) {
          nomValue = 'Utilisateur inconnu';
        }
      }

      return Utilisateur(
        id: json['id'] is int ? json['id'] : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
        nom: nomValue,
        photoProfil: json['photoProfil']?.toString(),
      );
    } catch (e) {
      print('❌ Erreur lors du parsing de Utilisateur: $e');
      print('📋 JSON reçu: $json');
      return Utilisateur(nom: 'Utilisateur inconnu');
    }
  }
}