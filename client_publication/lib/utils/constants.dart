import 'package:flutter/foundation.dart';

class Constants {
  /// URL complète du backend en production (Railway ou Render).
  /// Après déploiement Railway, remplacez par votre URL, ex. :
  /// https://fasojob-api-production.up.railway.app
  ///
  /// Ou au build : `flutter build apk --release --dart-define=API_BASE_URL=https://votre-app.up.railway.app`
  static const String _prodBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fasojob-api.onrender.com',
  );

  /// Développement local — hôte sans `http://` ni port.
  static const String _androidDevHost = String.fromEnvironment(
    'DEV_API_HOST',
    defaultValue: '10.0.2.2',
  );

  static const int _devPort = 8000;

  static String get _devHost {
    if (kIsWeb) return '127.0.0.1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidDevHost;
    }
    return '127.0.0.1';
  }

  /// Release (APK testeurs) → Render HTTPS. Debug → machine locale.
  static String get baseUrl {
    if (kReleaseMode) {
      return _prodBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }
    return 'http://$_devHost:$_devPort';
  }

  static String get apiBaseUrl => '$baseUrl/api';

  static String get publicationsUrl => '$apiBaseUrl/publications';
  static String get utilisateursUrl => '$apiBaseUrl/utilisateurs';
  static String get fichiersUrl => '$baseUrl/media';
}
