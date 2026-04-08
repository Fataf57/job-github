# Backend Django (DRF) pour l'application Job

Ce backend Django remplace le backend Spring Boot et fournit les mêmes fonctionnalités via Django REST Framework.

## Installation

1. Installer les dépendances :
```bash
pip3 install -r requirements.txt
```

2. Créer les migrations :
```bash
python3 manage.py makemigrations
python3 manage.py migrate
```

3. Créer un superutilisateur (optionnel) :
```bash
python3 manage.py createsuperuser
```

## Démarrage du serveur

Pour démarrer le serveur sur le port 8080 (comme le backend Spring Boot) :

```bash
python3 manage.py runserver 0.0.0.0:8080
```

## Endpoints API

Les endpoints sont identiques à ceux du backend Spring Boot :

- **Utilisateurs** : `/api/utilisateurs/`
  - `POST /api/utilisateurs/create` - Créer un utilisateur
  - `POST /api/utilisateurs/login` - Connexion
  - `GET /api/utilisateurs/` - Liste des utilisateurs
  - `GET /api/utilisateurs/{id}` - Détails d'un utilisateur
  - `PUT /api/utilisateurs/{id}/update` - Mettre à jour un utilisateur

- **Publications** : `/api/publications/`
  - `POST /api/publications/create` - Créer une publication
  - `GET /api/publications/tout` - Liste des publications
  - `GET /api/publications/{id}` - Détails d'une publication
  - `PUT /api/publications/update/{id}` - Mettre à jour une publication
  - `DELETE /api/publications/delete/{id}` - Supprimer une publication
  - `GET /api/publications/section/{section}` - Publications par section
  - `GET /api/publications/utilisateur/{id}` - Publications d'un utilisateur
  - `GET /api/publications/images/{filename}` - Servir une image
  - `GET /api/publications/videos/{filename}` - Servir une vidéo
  - `GET /api/publications/docs/{filename}` - Servir un PDF

- **Sections** : `/api/sections/`
  - `POST /api/sections/create` - Créer une section
  - `GET /api/sections/` - Liste des sections
  - `GET /api/sections/{id}` - Détails d'une section

## Nettoyage des publications expirées

Pour supprimer automatiquement les publications expirées, exécutez :

```bash
python3 manage.py cleanup_expired_publications
```

Vous pouvez configurer un cron job pour exécuter cette commande régulièrement (par exemple, toutes les heures) :

```bash
0 * * * * cd /chemin/vers/django-backend && python3 manage.py cleanup_expired_publications
```

## Configuration Flutter

Le frontend Flutter doit pointer vers le même port (8080). Assurez-vous que l'URL dans `client_publication/lib/utils/constants.dart` correspond à l'adresse IP de votre machine.

## Structure des fichiers

Les fichiers uploadés (images, vidéos, PDFs) sont stockés dans :
- `media/publications/images/`
- `media/publications/videos/`
- `media/publications/docs/`

