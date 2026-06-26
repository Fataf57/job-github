import 'constants.dart';

/// Construit l'URL complète d'un fichier publication (image, PDF, etc.).
String buildPublicationFileUrl(String? filePath) {
  if (filePath == null || filePath.trim().isEmpty) return '';

  final path = filePath.trim();
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  if (path.startsWith('/api/publications/')) {
    return '${Constants.baseUrl}$path';
  }

  if (path.startsWith('/media/')) {
    return '${Constants.baseUrl}$path';
  }

  if (path.startsWith('/')) {
    return '${Constants.baseUrl}$path';
  }

  // Chemin relatif : deviner images vs docs
  if (path.toLowerCase().contains('pdf') || path.startsWith('docs/')) {
    final name = path.replaceFirst('docs/', '');
    return '${Constants.publicationsUrl}/docs/$name';
  }

  return '${Constants.fichiersUrl}/publications/$path';
}
