// services/publication_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/publication.dart';
import '../utils/constants.dart';

class ReferenceLists {
  final List<String> domaines;
  final List<String> localites;
  final List<String> sections;
  final List<String> sexeOptions;

  ReferenceLists({
    required this.domaines,
    required this.localites,
    required this.sections,
    required this.sexeOptions,
  });

  factory ReferenceLists.fromJson(Map<String, dynamic> json) {
    return ReferenceLists(
      domaines: List<String>.from(json['domaines'] ?? []),
      localites: List<String>.from(json['localites'] ?? []),
      sections: List<String>.from(json['sections'] ?? []),
      sexeOptions: List<String>.from(json['sexeOptions'] ?? []),
    );
  }
}

class PaginatedPublications {
  final int count;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;
  final List<Publication> results;

  PaginatedPublications({
    required this.count,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
    required this.results,
  });

  factory PaginatedPublications.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? [];
    final publications = <Publication>[];
    for (var i = 0; i < rawResults.length; i++) {
      try {
        publications.add(Publication.fromJson(rawResults[i]));
      } catch (e) {
        print('❌ Erreur parsing publication $i: $e');
      }
    }
    return PaginatedPublications(
      count: json['count'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
      currentPage: json['currentPage'] ?? 1,
      pageSize: json['pageSize'] ?? 20,
      hasNext: json['hasNext'] ?? false,
      hasPrevious: json['hasPrevious'] ?? false,
      results: publications,
    );
  }
}

class PublicationService {
  static String get baseUrl => Constants.publicationsUrl;

  /// Récupère les listes de référence depuis le backend (domaines, localités, sections, etc.)
  Future<ReferenceLists> fetchReferenceLists() async {
    try {
      print('🔍 Récupération des listes de référence depuis: $baseUrl/references');
      final response = await http.get(
        Uri.parse('$baseUrl/references'),
        headers: {
          "Accept": "application/json",
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 30 secondes');
        },
      );
      
      print('📡 Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('✅ Listes de référence reçues');
        return ReferenceLists.fromJson(jsonResponse);
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        throw Exception('Échec du chargement des listes de référence: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des listes de référence: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<PaginatedPublications> fetchPublications({
    int? utilisateurId,
    String? localite,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      print('🔍 Récupération des publications (page $page) depuis: $baseUrl/tout');
      final params = <String, String>{'page': page.toString(), 'pageSize': pageSize.toString()};
      if (utilisateurId != null) params['utilisateur_id'] = utilisateurId.toString();
      if (localite != null && localite.isNotEmpty && localite != 'Tous') {
        params['localite'] = localite;
      }
      final uri = Uri.parse('$baseUrl/tout').replace(queryParameters: params);

      final response = await http.get(uri, headers: {"Accept": "application/json"}).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout: La requête a pris plus de 30 secondes'),
      );

      print('📡 Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final paginated = PaginatedPublications.fromJson(decoded);
        print('✅ Page ${paginated.currentPage}/${paginated.totalPages} — ${paginated.results.length} publications');
        return paginated;
      } else {
        throw Exception('Échec du chargement: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau fetchPublications: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<PaginatedPublications> fetchBySection(
    String section, {
    int? utilisateurId,
    String? localite,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      print('🔍 Section "$section" page $page');
      final params = <String, String>{'page': page.toString(), 'pageSize': pageSize.toString()};
      if (utilisateurId != null) params['utilisateur_id'] = utilisateurId.toString();
      if (localite != null && localite.isNotEmpty && localite != 'Tous') {
        params['localite'] = localite;
      }
      final uri = Uri.parse('$baseUrl/section/$section').replace(queryParameters: params);

      final response = await http.get(uri, headers: {"Accept": "application/json"}).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout: La requête a pris plus de 30 secondes'),
      );

      print('📡 Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final paginated = PaginatedPublications.fromJson(decoded);
        print('✅ Page ${paginated.currentPage}/${paginated.totalPages} — ${paginated.results.length} résultats pour "$section"');
        return paginated;
      } else {
        throw Exception('Échec du chargement: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur réseau fetchBySection: $e');
      if (e.toString().contains('Failed host lookup')) {
        print('💡 URL actuelle: ${Constants.baseUrl}');
      }
      throw Exception('Erreur réseau: $e');
    }
  }

  Future<Publication?> createPublication({
    required String titre,
    required String contenuTexte,
    required int auteurId,
    required String section,
    String? niveau,
    List<String>? domaines, // Liste de domaines (remplace le champ domaine unique)
    String? localite,
    String? sexe,
    String? dateLimite,
    List<String>? imagesPaths, // Liste de chemins d'images
    String? pdfPath,
    Uint8List? pdfBytes,
    String? pdfFilename,
    String? telephonePostuler,
    String? emailPostuler,
    String? whatsappPostuler,
    String? depotPhysiquePostuler,
  }) async {
    try {
      print('🔍 Création d\'une publication vers: $baseUrl/create');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/create'),
      );

      // Ajouter les champs texte
      request.fields['titre'] = titre;
      request.fields['contenuTexte'] = contenuTexte;
      request.fields['auteurId'] = auteurId.toString();
      request.fields['section'] = section;
      
      if (niveau != null && niveau.isNotEmpty) {
        request.fields['niveau'] = niveau;
      }
      // Envoyer les domaines comme une liste
      // Pour MultipartRequest, on envoie chaque domaine avec la clé 'domaines[]'
      if (domaines != null && domaines.isNotEmpty) {
        // Le backend Django attend request.POST.getlist('domaines[]')
        // On envoie chaque domaine individuellement avec la même clé
        for (var domaine in domaines) {
          // Utiliser addAll avec une Map pour chaque domaine
          final domainMap = <String, String>{'domaines[]': domaine};
          request.fields.addAll(domainMap);
        }
      }
      if (localite != null && localite.isNotEmpty) {
        request.fields['localite'] = localite;
      }
      if (sexe != null && sexe.isNotEmpty) {
        request.fields['sexe'] = sexe;
      }
      if (dateLimite != null && dateLimite.isNotEmpty) {
        request.fields['dateLimite'] = dateLimite;
      }
      if (telephonePostuler != null && telephonePostuler.isNotEmpty) {
        request.fields['telephonePostuler'] = telephonePostuler;
      }
      if (emailPostuler != null && emailPostuler.isNotEmpty) {
        request.fields['emailPostuler'] = emailPostuler;
      }
      if (whatsappPostuler != null && whatsappPostuler.isNotEmpty) {
        request.fields['whatsappPostuler'] = whatsappPostuler;
      }
      if (depotPhysiquePostuler != null && depotPhysiquePostuler.isNotEmpty) {
        request.fields['depotPhysiquePostuler'] = depotPhysiquePostuler;
      }

      // Ajouter les images (plusieurs)
      if (imagesPaths != null && imagesPaths.isNotEmpty) {
        for (final path in imagesPaths) {
          request.files.add(
            await http.MultipartFile.fromPath('images[]', path),
          );
        }
      }
      if (pdfBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'pdf',
            pdfBytes,
            filename: (pdfFilename != null && pdfFilename.isNotEmpty)
                ? pdfFilename
                : 'document.pdf',
          ),
        );
      } else if (pdfPath != null && pdfPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('pdf', pdfPath),
        );
      }

      // Envoyer la requête avec timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60), // Timeout plus long pour les uploads de fichiers
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 60 secondes. Vérifiez votre connexion réseau.');
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout lors de la lecture de la réponse du serveur.');
        },
      );

      print('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        print('✅ Publication créée avec succès');
        return Publication.fromJson(jsonResponse);
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        print('📋 Response body: ${response.body}');
        throw Exception('Échec de la création: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Erreur lors de la création: $e');
      
      // Messages d'erreur plus clairs selon le type d'erreur
      String errorMessage = 'Erreur lors de la création';
      
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Aucun chemin d\'accès')) {
        errorMessage = 'Impossible de se connecter au serveur.\n'
            'Vérifiez que:\n'
            '• Le serveur Django est démarré sur ${Constants.baseUrl}\n'
            '• Votre appareil est connecté au même réseau\n'
            '• L\'adresse IP est correcte';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'La requête a pris trop de temps.\n'
            'Vérifiez votre connexion réseau et réessayez.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Le serveur refuse la connexion.\n'
            'Vérifiez que le serveur Django est bien démarré.';
      } else {
        errorMessage = 'Erreur: $e';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Récupérer toutes les publications d'un auteur (recruteur)
  Future<PaginatedPublications> fetchPublicationsByAuteur(int utilisateurId, {int page = 1, int pageSize = 50}) async {
    try {
      final uri = Uri.parse('$baseUrl/utilisateur/$utilisateurId')
          .replace(queryParameters: {'page': page.toString(), 'pageSize': pageSize.toString()});
      final response = await http.get(uri, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return PaginatedPublications.fromJson(json.decode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Erreur: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Mettre à jour une publication existante
  Future<Publication?> updatePublication({
    required int id,
    required String titre,
    required String contenuTexte,
    required String section,
    List<String>? domaines,
    String? localite,
    String? sexe,
    String? dateLimite,
    List<String>? imagesPaths,
    String? pdfPath,
    Uint8List? pdfBytes,
    String? pdfFilename,
    String? telephonePostuler,
    String? emailPostuler,
    String? whatsappPostuler,
    String? depotPhysiquePostuler,
  }) async {
    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/update/$id'));
      request.fields['titre'] = titre;
      request.fields['contenuTexte'] = contenuTexte;
      request.fields['section'] = section;
      if (domaines != null && domaines.isNotEmpty) {
        for (var d in domaines) request.fields.addAll({'domaines[]': d});
      }
      if (localite != null && localite.isNotEmpty) request.fields['localite'] = localite;
      if (sexe != null && sexe.isNotEmpty) request.fields['sexe'] = sexe;
      if (dateLimite != null && dateLimite.isNotEmpty) request.fields['dateLimite'] = dateLimite;
      if (telephonePostuler != null && telephonePostuler.isNotEmpty) request.fields['telephonePostuler'] = telephonePostuler;
      if (emailPostuler != null && emailPostuler.isNotEmpty) request.fields['emailPostuler'] = emailPostuler;
      if (whatsappPostuler != null && whatsappPostuler.isNotEmpty) request.fields['whatsappPostuler'] = whatsappPostuler;
      if (depotPhysiquePostuler != null && depotPhysiquePostuler.isNotEmpty) request.fields['depotPhysiquePostuler'] = depotPhysiquePostuler;
      if (imagesPaths != null && imagesPaths.isNotEmpty) {
        for (final path in imagesPaths) {
          request.files.add(await http.MultipartFile.fromPath('images[]', path));
        }
      }
      if (pdfBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'pdf',
            pdfBytes,
            filename: (pdfFilename != null && pdfFilename.isNotEmpty)
                ? pdfFilename
                : 'document.pdf',
          ),
        );
      } else if (pdfPath != null && pdfPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('pdf', pdfPath));
      }
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Publication.fromJson(json.decode(response.body));
      }
      throw Exception('Échec mise à jour: ${response.statusCode} - ${response.body}');
    } catch (e) {
      throw Exception('Erreur: $e');
    }
  }

  /// Supprimer une publication
  Future<bool> deletePublication(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/delete/$id'),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Ajouter une publication aux favoris
  Future<bool> addFavori(int publicationId, int utilisateurId) async {
    try {
      print('🔍 Ajout de la publication $publicationId aux favoris pour l\'utilisateur $utilisateurId');
      final response = await http.post(
        Uri.parse('$baseUrl/favoris/add/$publicationId'),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          'utilisateur_id': utilisateurId.toString(),
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 30 secondes');
        },
      );

      print('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        print('✅ Publication ajoutée aux favoris');
        return jsonResponse['is_favori'] ?? true;
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        throw Exception('Échec de l\'ajout aux favoris: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ajout aux favoris: $e');
      throw Exception('Erreur lors de l\'ajout aux favoris: $e');
    }
  }

  /// Retirer une publication des favoris
  Future<bool> removeFavori(int publicationId, int utilisateurId) async {
    try {
      print('🔍 Retrait de la publication $publicationId des favoris pour l\'utilisateur $utilisateurId');
      final uri = Uri.parse('$baseUrl/favoris/remove/$publicationId')
          .replace(queryParameters: {'utilisateur_id': utilisateurId.toString()});
      
      final response = await http.delete(
        uri,
        headers: {
          "Accept": "application/json",
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 30 secondes');
        },
      );

      print('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('✅ Publication retirée des favoris');
        return jsonResponse['is_favori'] ?? false;
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        throw Exception('Échec du retrait des favoris: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors du retrait des favoris: $e');
      throw Exception('Erreur lors du retrait des favoris: $e');
    }
  }

  /// Vérifier si une publication est dans les favoris
  Future<bool> checkFavori(int publicationId, int utilisateurId) async {
    try {
      print('🔍 Vérification si la publication $publicationId est dans les favoris');
      final uri = Uri.parse('$baseUrl/favoris/check/$publicationId')
          .replace(queryParameters: {'utilisateur_id': utilisateurId.toString()});
      
      final response = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 30 secondes');
        },
      );

      print('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final isFavori = jsonResponse['is_favori'] ?? false;
        print('✅ Publication ${isFavori ? "est" : "n\'est pas"} dans les favoris');
        return isFavori;
      } else {
        print('❌ Erreur HTTP: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification des favoris: $e');
      return false;
    }
  }

  /// Récupérer toutes les publications favorites (filtrage métier côté serveur).
  Future<List<Publication>> getFavoris(int utilisateurId, {String? localite}) async {
    try {
      print('🔍 Récupération des favoris pour l\'utilisateur $utilisateurId');
      List<Publication> allFavoris = [];
      int page = 1;
      bool hasNext = true;

      while (hasNext) {
        final params = <String, String>{
          'page': page.toString(),
          'pageSize': '50',
          'utilisateur_id': utilisateurId.toString(),
        };
        if (localite != null && localite.isNotEmpty && localite != 'Tous') {
          params['localite'] = localite;
        }
        final uri = Uri.parse('$baseUrl/favoris/$utilisateurId')
            .replace(queryParameters: params);

        final response = await http.get(uri, headers: {"Accept": "application/json"}).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Timeout'),
        );

        if (response.statusCode == 200) {
          final paginated = PaginatedPublications.fromJson(
              json.decode(response.body) as Map<String, dynamic>);
          allFavoris.addAll(paginated.results);
          hasNext = paginated.hasNext;
          page++;
        } else {
          throw Exception('Échec du chargement des favoris: ${response.statusCode}');
        }
      }

      print('✅ ${allFavoris.length} favoris récupérés');
      return allFavoris;
    } catch (e) {
      print('❌ Erreur getFavoris: $e');
      throw Exception('Erreur réseau: $e');
    }
  }
}