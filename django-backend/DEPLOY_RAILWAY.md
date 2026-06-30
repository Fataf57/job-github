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
| **Root Directory** | *(vide)* ou `django-backend` (les deux fonctionnent avec le Dockerfile) |
| **Custom Build Command** | *(vide)* |
| **Custom Start Command** | *(vide)* |

Le déploiement utilise le **Dockerfile** (Gunicorn + migrations au démarrage).

## 3. Lier PostgreSQL (obligatoire)

Sans cela, la base Railway reste vide et le démarrage peut échouer.

1. Service **fasojob-api** → **Variables**
2. **+ New Variable** → **Add Reference**
3. Choisir **fasojob-db** → variable **`DATABASE_URL`**
4. Sauvegarder → **Redeploy**

Vérification : **fasojob-db** → **Database** → **Data** → les tables Django (`auth_user`, `publications_*`, etc.) apparaissent après un déploiement réussi.

## 4. Variables d'environnement

Dans le service web → **Variables** :

| Variable | Valeur |
|----------|--------|
| `DEBUG` | `false` |
| `SECRET_KEY` | clé longue aléatoire (50+ caractères) |
| `DATABASE_URL` | référence PostgreSQL (étape 3) |
| `SENDGRID_API_KEY` | clé API SendGrid (voir section ci-dessous) |
| `DEFAULT_FROM_EMAIL` | expéditeur vérifié dans SendGrid |

### Emails de verification (SendGrid)

1. Creer un compte sur [sendgrid.com](https://sendgrid.com)
2. **Settings** → **API Keys** → creer une cle avec permission **Mail Send**
3. **Settings** → **Sender Authentication** → verifier un **Single Sender** ou votre domaine
4. Sur Railway (**fasojob-api** → **Variables**), ajouter :

| Variable | Valeur |
|----------|--------|
| `SENDGRID_API_KEY` | votre cle API SendGrid (`SG.xxxx...`) |
| `DEFAULT_FROM_EMAIL` | email verifie dans SendGrid (ex. `noreply@votredomaine.com`) |

SendGrid configure automatiquement le SMTP (`smtp.sendgrid.net`, user `apikey`).

En local, sans `SENDGRID_API_KEY`, le code s'affiche dans la console Django et dans l'app (mode dev).

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
