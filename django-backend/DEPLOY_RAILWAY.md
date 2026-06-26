# Déployer FASO JOB sur Railway

## 1. Créer le projet (écran « New project »)

1. Cliquer sur **GitHub Repository**
2. Autoriser Railway à accéder à GitHub si demandé
3. Choisir le dépôt **Job-github**
4. Railway crée un service web — ouvrir ce service → **Settings**

## 2. Configurer le service web

Dans **Settings** du service :

| Paramètre | Valeur |
|-----------|--------|
| **Root Directory** | *(laisser vide)* |
| **Custom Build Command** | *(laisser vide — utilise `railway.toml` à la racine)* |
| **Custom Start Command** | *(laisser vide — utilise `railway.toml`)* |

> **Important** : ne remplissez pas la commande de build dans l’interface **et** dans `railway.toml` en même temps — cela provoque l’erreur `chmod +x chmod +x build.sh`.

**Alternative** : Root Directory = `django-backend`, champs build/start vides, alors `django-backend/railway.toml` s’applique.

### Erreur « Healthcheck failure » (builder NIXPACKS)

- Cause : `builder = "NIXPACKS"` est obsolète — le proxy Railway ne joint plus le conteneur.
- Fix : utiliser `builder = "RAILPACK"` dans `railway.toml` (déjà configuré dans ce dépôt).

### Erreur « Healthcheck failure » (base de données)

- Cause fréquente : `DATABASE_URL` absent au **build** → migrations sur SQLite, puis PostgreSQL vide au démarrage → Django plante sur `/health/`.
- Fix : le script `start.sh` lance `migrate` **au démarrage** (avec la vraie `DATABASE_URL`).
- Vérifier : service web → **Variables** → `DATABASE_URL` = **Reference** vers **fasojob-db**.

## 3. Ajouter PostgreSQL

1. Dans le projet Railway : **+ New** → **Database** → **PostgreSQL**
2. Ouvrir le service web → **Variables** → **New Variable** → **Add Reference**
3. Choisir la base PostgreSQL → variable **`DATABASE_URL`**

## 4. Variables d'environnement

Dans le service web → **Variables** :

| Variable | Valeur |
|----------|--------|
| `DEBUG` | `false` |
| `SECRET_KEY` | clé longue aléatoire (50+ caractères) |
| `DATABASE_URL` | référence PostgreSQL (étape 3) |

Optionnel — emails (Gmail) :

| Variable | Valeur |
|----------|--------|
| `EMAIL_HOST` | `smtp.gmail.com` |
| `EMAIL_PORT` | `587` |
| `EMAIL_HOST_USER` | votre@gmail.com |
| `EMAIL_HOST_PASSWORD` | mot de passe d'application Gmail |
| `EMAIL_USE_TLS` | `true` |
| `DEFAULT_FROM_EMAIL` | votre@gmail.com |

Railway injecte automatiquement `RAILWAY_PUBLIC_DOMAIN` (hostname public).

## 5. Exposer l'API (URL publique)

1. Service web → **Settings** → **Networking**
2. **Generate Domain**
3. Noter l'URL, ex. `https://fasojob-api-production.up.railway.app`

## 6. Vérifier le déploiement

Dans un navigateur :

- `https://VOTRE-DOMAINE.up.railway.app/health/` → `{"status":"ok",...}`
- `https://VOTRE-DOMAINE.up.railway.app/api/publications/references` → JSON

## 7. Mettre à jour l'app Flutter

Modifier `client_publication/lib/utils/constants.dart` → `defaultValue` de `API_BASE_URL`

Ou au build :

```bash
cd client_publication
flutter build apk --release --dart-define=API_BASE_URL=https://VOTRE-DOMAINE.up.railway.app
```

Puis redistribuer l'APK (Firebase App Distribution).

## 8. Admin Django (optionnel)

Dans Railway → service web → **Shell** :

```bash
python manage.py createsuperuser
```

Puis : `https://VOTRE-DOMAINE.up.railway.app/admin/`

## Migration depuis Render

1. Déployer d'abord sur Railway **sans couper Render**
2. Exporter la base Render : `pg_dump` → importer dans PostgreSQL Railway
3. Les fichiers uploadés (images, PDF) sur le disque Render ne migrent pas automatiquement
4. Basculer l'URL dans l'APK, puis arrêter Render

## Limitations

| Élément | Comportement |
|--------|----------------|
| Base PostgreSQL | Persistante ✅ |
| Fichiers uploadés | Disque éphémère — peuvent disparaître au redéploiement |
| Coût | Trial Railway (~5 $ / 30 jours), puis facturation à l'usage |

Pour des fichiers persistants en production : AWS S3 ou Cloudinary.
