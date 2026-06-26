import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/phone_utils.dart';

class ApiService {
  final String baseUrl = Constants.utilisateursUrl; // 🖥️ Adresse du backend

  static String _parseApiError(Map<String, dynamic> errorData) {
    if (errorData.containsKey('telephone')) {
      final tel = errorData['telephone'];
      if (tel is List && tel.isNotEmpty) return tel.first.toString();
      return tel.toString();
    }
    if (errorData.containsKey('errors')) {
      final errors = errorData['errors'];
      if (errors is Map) {
        return errors.entries.map((e) => "${e.key}: ${e.value}").join(", ");
      }
      return errors.toString();
    }
    if (errorData.containsKey('message')) {
      return errorData['message'].toString();
    }
    if (errorData.containsKey('error')) {
      return errorData['error'].toString();
    }
    return "Erreur lors de la création";
  }

  Future<Map<String, dynamic>> registerUser(Utilisateur user) async {
    try {
      print("🔵 Tentative d'enregistrement vers: $baseUrl/create");
      print("📤 Données envoyées: ${jsonEncode(user.toJson())}");
      
      final response = await http.post(
        Uri.parse("$baseUrl/create"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          ...user.toJson(),
          'telephone': normalizeTelephone(user.telephone),
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 10 secondes');
        },
      );

      print("📡 Réponse reçue - Status: ${response.statusCode}");
      print("📦 Body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Utilisateur créé avec succès!");
        final body = jsonDecode(response.body);
        final bodyMap = body is Map<String, dynamic>
            ? body
            : Map<String, dynamic>.from(body as Map);
        return {
          'success': true,
          'message': bodyMap['message'],
          if (bodyMap['verification_code'] != null)
            'verification_code': bodyMap['verification_code'].toString(),
        };
      } else {
        print("❌ Erreur HTTP: ${response.statusCode}");
        print("❌ Message: ${response.body}");
        
        // Essayer de parser les erreurs pour afficher un message plus clair
        String errorMessage = "Erreur lors de la création";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMessage = _parseApiError(errorData);
          } else if (errorData is Map) {
            errorMessage = _parseApiError(Map<String, dynamic>.from(errorData));
          }
        } catch (e) {
          // Si on ne peut pas parser, on garde le message brut
          if (response.body.isNotEmpty) {
            errorMessage = response.body.length > 100 
                ? "${response.body.substring(0, 100)}..." 
                : response.body;
          }
        }
        
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print("❌ Erreur lors de l'enregistrement: $e");
      String errorMessage = "Erreur réseau: $e";
      if (e.toString().contains('Failed host lookup')) {
        errorMessage = "Problème de connexion réseau - Vérifiez l'URL du serveur";
        print("⚠️ $errorMessage");
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = "Le serveur Django n'est pas accessible - Vérifiez qu'il est démarré";
        print("⚠️ $errorMessage");
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  /// Connexion et récupération de l'utilisateur
  Future<Utilisateur?> login({required String telephone, required String motDePasse}) async {
    try {
      print("🔵 Tentative de connexion vers: $baseUrl/login");
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "telephone": normalizeTelephone(telephone),
          "motDePasse": motDePasse,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 10 secondes');
        },
      );

      print("📡 Réponse reçue - Status: ${response.statusCode}");
      print("📦 Body: ${response.body}");

      if (response.statusCode == 200) {
        final userMap = jsonDecode(response.body) as Map<String, dynamic>;
        return Utilisateur.fromJson(userMap);
      }
      if (response.statusCode == 403) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            print("⚠️ ${body['message']}");
          }
        } catch (_) {}
      } else {
        print("❌ Login failed: ${response.statusCode} ${response.body}");
      }
      return null;
    } catch (e) {
      print("❌ Erreur lors de la connexion: $e");
      if (e.toString().contains('Failed host lookup')) {
        print("⚠️ Problème de connexion réseau - Vérifiez l'URL du serveur");
      } else if (e.toString().contains('Connection refused')) {
        print("⚠️ Le serveur Django n'est pas accessible - Vérifiez qu'il est démarré");
      }
      return null;
    }
  }

  /// Récupérer un utilisateur par ID
  Future<Utilisateur?> getUserById(int id) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/$id"),
        headers: {"Content-Type": "application/json"},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 10 secondes');
        },
      );

      if (response.statusCode == 200) {
        final userMap = jsonDecode(response.body) as Map<String, dynamic>;
        return Utilisateur.fromJson(userMap);
      } else {
        print("Erreur lors de la récupération de l'utilisateur: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'utilisateur: $e");
      return null;
    }
  }

  /// Vérifier le code reçu par email ou téléphone
  Future<Map<String, dynamic>> verifyEmailCode({
    String? email,
    String? telephone,
    required String code,
  }) async {
    try {
      final body = <String, dynamic>{'code': code};
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      if (telephone != null && telephone.trim().isNotEmpty) {
        body['telephone'] = normalizeTelephone(telephone.trim());
      }

      final response = await http.post(
        Uri.parse("$baseUrl/verify-email"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      final bodyMap = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode == 200) {
        return {'success': true, 'message': bodyMap['message'] ?? 'Compte vérifié !'};
      }
      return {'success': false, 'message': bodyMap['message'] ?? 'Code incorrect.'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Renvoyer un nouveau code de vérification
  Future<Map<String, dynamic>> resendVerificationCode({
    String? email,
    String? telephone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      if (telephone != null && telephone.trim().isNotEmpty) {
        body['telephone'] = normalizeTelephone(telephone.trim());
      }

      final response = await http.post(
        Uri.parse("$baseUrl/resend-verification"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body);
      final bodyMap = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': bodyMap['message'] ?? 'Code renvoyé.',
          if (bodyMap['verification_code'] != null)
            'verification_code': bodyMap['verification_code'].toString(),
        };
      }
      return {'success': false, 'message': bodyMap['message'] ?? 'Erreur lors de l\'envoi.'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Mettre à jour un utilisateur
  Future<Utilisateur?> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: La requête a pris plus de 10 secondes');
        },
      );
      
      if (response.statusCode == 200) {
        // Le backend retourne l'utilisateur mis à jour
        final userMap = jsonDecode(response.body) as Map<String, dynamic>;
        return Utilisateur.fromJson(userMap);
      } else {
        print("Update failed: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (e) {
      print("Erreur lors de la mise à jour: $e");
      return null;
    }
  }
}
