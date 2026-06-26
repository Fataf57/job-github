import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/login_page.dart';
import 'pages/publication_page.dart';
import 'pages/recruiter_profile_page.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';

void main() async {
  // Initialise les canaux natifs avant runApp (nécessaire pour SystemChannels).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Pré-chauffe l'IME Android : le moteur du clavier s'initialise en arrière-plan
  // dès le démarrage, avant que l'utilisateur tape sur un champ.
  // Sans ça, le 1er appel coûte 200-400 ms de cold start.
  _prewarmKeyboard();

  runApp(const MyApp());
}

/// Envoie un show+hide invisible au système pour forcer Android à charger
/// le service IME en avance. L'utilisateur ne voit rien.
void _prewarmKeyboard() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Utilisateur? _user;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      final user = await _authService.getCurrentUser();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FASO JOB',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _user == null
              ? const LoginPage()
              : _user!.isRecruteur
                  ? const RecruiterProfilePage()
                  : const PublicationPage(),
    );
  }
}
