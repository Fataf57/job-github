# Migration Spring Boot → Django (DRF)

## ✅ Migration terminée

Le backend Spring Boot a été entièrement migré vers Django REST Framework (DRF). Tous les endpoints et fonctionnalités ont été reproduits.

## 📁 Structure créée

```
django-backend/
├── job_api/              # Configuration principale Django
├── utilisateurs/         # App pour la gestion des utilisateurs
├── publications/         # App pour la gestion des publications
├── sections/             # App pour la gestion des sections
├── media/                # Dossier pour les fichiers uploadés
│   └── publications/
│       ├── images/
│       ├── videos/
│       └── docs/
├── requirements.txt      # Dépendances Python
├── README.md            # Documentation
└── start_server.sh      # Script de démarrage
```

## 🔄 Correspondance des endpoints

Tous les endpoints Spring Boot ont été reproduits :

### Utilisateurs (`/api/utilisateurs/`)
- ✅ `POST /create` → Créer un utilisateur
- ✅ `POST /login` → Connexion
- ✅ `GET /` → Liste des utilisateurs
- ✅ `GET /{id}` → Détails d'un utilisateur
- ✅ `PUT /{id}` → Mettre à jour un utilisateur

### Publications (`/api/publications/`)
- ✅ `POST /create` → Créer une publication (avec fichiers)
- ✅ `GET /tout` → Liste des publications non expirées
- ✅ `GET /{id}` → Détails d'une publication
- ✅ `PUT /update/{id}` → Mettre à jour une publication
- ✅ `DELETE /delete/{id}` → Supprimer une publication
- ✅ `GET /section/{section}` → Publications par section
- ✅ `GET /utilisateur/{id}` → Publications d'un utilisateur
- ✅ `DELETE /delete/all` → Supprimer toutes les publications
- ✅ `GET /images/{filename}` → Servir une image
- ✅ `GET /videos/{filename}` → Servir une vidéo
- ✅ `GET /docs/{filename}` → Servir un PDF

### Sections (`/api/sections/`)
- ✅ `POST /create` → Créer une section
- ✅ `GET /` → Liste des sections
- ✅ `GET /{id}` → Détails d'une section

## 🚀 Démarrage

1. **Installer les dépendances** (si pas déjà fait) :
```bash
cd django-backend
pip3 install -r requirements.txt
```

2. **Appliquer les migrations** (si pas déjà fait) :
```bash
python3 manage.py migrate
```

3. **Démarrer le serveur** :
```bash
# Option 1 : Utiliser le script
./start_server.sh

# Option 2 : Commande directe
python3 manage.py runserver 0.0.0.0:8080
```

Le serveur sera accessible sur `http://0.0.0.0:8080` (identique au backend Spring Boot).

## 🔧 Configuration Flutter

Le frontend Flutter devrait fonctionner sans modification car :
- ✅ Les endpoints sont identiques
- ✅ Les réponses JSON utilisent le même format (camelCase)
- ✅ Le port est le même (8080)
- ✅ CORS est configuré pour accepter toutes les origines

Assurez-vous que l'URL dans `client_publication/lib/utils/constants.dart` pointe vers la bonne adresse IP de votre machine.

## 🗑️ Nettoyage des publications expirées

Pour supprimer automatiquement les publications expirées :

```bash
python3 manage.py cleanup_expired_publications
```

Pour automatiser (cron job toutes les heures) :
```bash
0 * * * * cd /chemin/vers/django-backend && python3 manage.py cleanup_expired_publications
```

## 📝 Notes importantes

1. **Base de données** : La base de données SQLite est créée automatiquement (`db.sqlite3`). Pour migrer les données existantes du backend Spring Boot, vous devrez créer un script de migration.

2. **Fichiers uploadés** : Les fichiers sont stockés dans `media/publications/`. Les URLs retournées sont relatives (`/api/publications/images/...`) et seront résolues automatiquement par Django.

3. **Sécurité** : En production, pensez à :
   - Changer `SECRET_KEY` dans `settings.py`
   - Désactiver `DEBUG = False`
   - Configurer `ALLOWED_HOSTS` correctement
   - Utiliser une base de données plus robuste (PostgreSQL, MySQL)
   - Ajouter l'authentification JWT si nécessaire

4. **Format des données** : Les serializers convertissent automatiquement les noms de champs Python (snake_case) en camelCase pour correspondre au format attendu par Flutter.

## ✨ Fonctionnalités implémentées

- ✅ Gestion complète des utilisateurs (CRUD + login)
- ✅ Gestion complète des publications (CRUD + upload de fichiers)
- ✅ Gestion des sections
- ✅ Filtrage des publications expirées
- ✅ Upload et service de fichiers (images, vidéos, PDFs)
- ✅ CORS configuré pour Flutter
- ✅ Commande de nettoyage des publications expirées
- ✅ Format JSON compatible avec Flutter (camelCase)

## 🎯 Prochaines étapes

1. Tester le backend avec le frontend Flutter
2. Migrer les données existantes si nécessaire
3. Configurer le nettoyage automatique des publications expirées (cron)
4. Optimiser pour la production si nécessaire

