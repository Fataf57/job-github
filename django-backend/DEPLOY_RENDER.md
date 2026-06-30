# Déployer FASO JOB sur Render (testeurs APK)

## 1. Pousser le code sur GitHub

Assurez-vous que le dépôt contient `django-backend/`, `client_publication/` (app Flutter, versionnée mais **non déployée** sur Render), `render.yaml` à la racine, et que `venv/` / `build/` ne sont **pas** versionnés.

Render ne déploie que le dossier `django-backend/` (voir `rootDir` dans `render.yaml`). Un `git push` envoie tout le monorepo sur GitHub ; seul le backend est reconstruit sur Render.

## 2. Créer le compte Render

1. [https://render.com](https://render.com) → inscription (GitHub recommandé)
2. **New** → **Blueprint**
3. Connecter le dépôt **Job-github**
4. Render détecte `render.yaml` → **Apply**

Cela crée :
- **fasojob-api** (Web Service Python)
- **fasojob-db** (PostgreSQL gratuit)

Attendre le premier déploiement (5–10 min). L'URL sera du type :

`https://fasojob-api.onrender.com`

## 3. Vérifier que l'API répond

Dans un navigateur :

- `https://fasojob-api.onrender.com/health/` → `{"status":"ok",...}`
- `https://fasojob-api.onrender.com/api/publications/references` → JSON (ou liste vide)

> **Offre gratuite** : le service « s'endort » après ~15 min d'inactivité. La **première** requête peut prendre 30–60 s.

## 4. Mettre à jour l'URL dans l'app Flutter

Si votre URL Render est différente de `https://fasojob-api.onrender.com`, modifiez :

`client_publication/lib/utils/constants.dart` → `defaultValue` de `API_BASE_URL`

Ou au build :

```bash
cd client_publication
flutter build apk --release --dart-define=API_BASE_URL=https://VOTRE-URL.onrender.com
```

## 5. Reconstruire et redistribuer l'APK

```bash
cd client_publication
flutter build apk --release
```

Uploader sur **Firebase App Distribution** :

`build/app/outputs/flutter-apk/app-release.apk`

## 6. Côté testeurs

1. Installer l'APK depuis l'email Firebase
2. **Pas besoin** du même Wi‑Fi que votre PC
3. Désactiver le VPN si des erreurs réseau persistent
4. La première ouverture peut être lente (réveil du serveur Render)

## Déploiement manuel (sans Blueprint)

1. **New** → **Web Service** → repo GitHub
2. **Root Directory** : `django-backend`
3. **Build Command** : `chmod +x build.sh start.sh && ./build.sh`
4. **Start Command** : `./start.sh`
5. **New** → **PostgreSQL** → lier `DATABASE_URL` au Web Service
6. Variables d'environnement :
   - `DEBUG` = `false`
   - `SECRET_KEY` = (générer une clé longue aléatoire)
   - `PYTHON_VERSION` = `3.12.0`

## 7. Codes de vérification (inscription) — SendGrid

Sans SendGrid, les codes s'affichent **dans l'app** (bandeau orange, mode dev) et dans les **logs Render**.

### Activer les vrais emails (SendGrid)

1. Compte sur [sendgrid.com](https://sendgrid.com)
2. **Settings → API Keys** → créer une clé avec permission **Mail Send**
3. **Settings → Sender Authentication** → vérifier un **Single Sender** (ex. `noreply@votredomaine.com`)

Dans Render → **fasojob-api** → **Environment** → ajouter :

| Variable | Valeur |
|----------|--------|
| `SENDGRID_API_KEY` | `SG.xxxxxxxxx...` |
| `DEFAULT_FROM_EMAIL` | email **exact** vérifié dans SendGrid |

Une fois SendGrid configuré, les codes partent par **vrai email** et ne s'affichent plus dans l'app.

### Compte bloqué

Sur l'écran de code, appuyez sur **« Renvoyer le code »** — un nouvel email sera envoyé.

## Limitations (offre gratuite)

| Élément | Comportement |
|--------|----------------|
| Base de données | PostgreSQL persistante ✅ |
| Fichiers uploadés (PDF, images) | Disque **éphémère** — peuvent disparaître après un redéploiement |
| Veille | 30–60 s au premier appel après inactivité |

Pour la production avec fichiers persistants : ajouter plus tard **AWS S3** ou **Cloudinary**.

## Admin Django (optionnel)

Dans le shell Render (**Shell** du service) :

```bash
python manage.py createsuperuser
```

Puis : `https://fasojob-api.onrender.com/admin/`
