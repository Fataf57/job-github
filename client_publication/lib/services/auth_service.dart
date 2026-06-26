import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Service de gestion de l'authentification et de la session utilisateur
class AuthService {
  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';

  /// Stocker l'utilisateur connecté
  Future<void> saveUser(Utilisateur user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setBool(_isLoggedInKey, true);
  }

  /// Récupérer l'utilisateur connecté
  Future<Utilisateur?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    
    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return Utilisateur.fromJson(userMap);
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }

  /// Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Déconnecter l'utilisateur
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  /// Mettre à jour l'utilisateur connecté
  Future<void> updateCurrentUser(Utilisateur user) async {
    await saveUser(user);
  }

  /// Récupérer l'ID de l'utilisateur connecté
  Future<int?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?.id;
  }
}

