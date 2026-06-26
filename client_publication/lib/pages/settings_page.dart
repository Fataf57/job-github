import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'login_page.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF42A5F5);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Annuler', style: TextStyle(color: _kSubtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── En-tête ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: const BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Paramètres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Liste des paramètres ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              children: [
                // Compte
                _buildGroupTitle('Compte'),
                _buildSettingsCard([
                  _buildTile(
                    icon: Icons.lock_outline,
                    iconBg: const Color(0xFF7C3AED),
                    title: 'Sécurité',
                    subtitle: 'Mot de passe et authentification',
                    onTap: () => _showComingSoon('Sécurité'),
                  ),
                ]),
                const SizedBox(height: 16),

                // Préférences
                _buildGroupTitle('Préférences'),
                _buildSettingsCard([
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    iconBg: const Color(0xFFD97706),
                    title: 'Notifications',
                    subtitle: 'Recevoir des alertes de nouvelles offres',
                    value: _notificationsEnabled,
                    onChanged: (v) =>
                        setState(() => _notificationsEnabled = v),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.language_outlined,
                    iconBg: const Color(0xFF059669),
                    title: 'Langue',
                    subtitle: 'Français',
                    onTap: () => _showComingSoon('Langue'),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.location_on_outlined,
                    iconBg: const Color(0xFFDC2626),
                    title: 'Localité par défaut',
                    subtitle: 'Toutes les régions',
                    onTap: () => _showComingSoon('Localité'),
                  ),
                ]),
                const SizedBox(height: 16),

                // À propos
                _buildGroupTitle('À propos'),
                _buildSettingsCard([
                  _buildTile(
                    icon: Icons.info_outline,
                    iconBg: const Color(0xFF0891B2),
                    title: 'Version de l\'application',
                    subtitle: '1.0.0',
                    onTap: null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('À jour',
                          style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.description_outlined,
                    iconBg: const Color(0xFF6B7280),
                    title: 'Conditions d\'utilisation',
                    subtitle: 'Consulter nos CGU',
                    onTap: () => _showComingSoon('CGU'),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.privacy_tip_outlined,
                    iconBg: const Color(0xFF6B7280),
                    title: 'Politique de confidentialité',
                    subtitle: 'Comment nous protégeons vos données',
                    onTap: () => _showComingSoon('Confidentialité'),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.help_outline,
                    iconBg: const Color(0xFF6B7280),
                    title: 'Aide & Support',
                    subtitle: 'Contacter notre équipe',
                    onTap: () => _showComingSoon('Aide'),
                  ),
                ]),
                const SizedBox(height: 16),

                // Serveur
                _buildGroupTitle('Connexion'),
                _buildSettingsCard([
                  _buildTile(
                    icon: Icons.dns_outlined,
                    iconBg: const Color(0xFF374151),
                    title: 'Serveur',
                    subtitle: Constants.baseUrl,
                    onTap: null,
                  ),
                ]),
                const SizedBox(height: 24),

                // Déconnexion
                if (_isLoggedIn)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Se déconnecter',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF2F2),
                        foregroundColor: const Color(0xFFDC2626),
                        elevation: 0,
                        side: const BorderSide(
                            color: Color(0xFFFCA5A5), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kSubtext,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
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
  }

  Widget _buildDivider() =>
      const Divider(height: 1, indent: 60, color: _kBorder);

  Widget _buildTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconBg, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: _kSubtext)),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right,
                  color: _kSubtext, size: 20)
              : null),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconBg, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: _kSubtext)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: _kPrimary,
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature : bientôt disponible'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }
}
