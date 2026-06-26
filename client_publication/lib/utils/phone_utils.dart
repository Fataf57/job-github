/// Normalise un numéro pour correspondre au format stocké côté serveur.
String normalizeTelephone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return trimmed;

  var d = digits;
  if (d.startsWith('00226') && d.length > 5) {
    d = d.substring(5);
  } else if (d.startsWith('00') && d.length > 2) {
    d = d.substring(2);
  }

  if (d.length == 9 && d.startsWith('0')) {
    return '+226${d.substring(1)}';
  }
  if (d.startsWith('226') && d.length == 11) {
    return '+$d';
  }
  if (d.length == 8) {
    return '+226$d';
  }
  if (trimmed.startsWith('+') || d.startsWith('226')) {
    return '+$d';
  }
  return d;
}
