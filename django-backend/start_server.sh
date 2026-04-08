#!/bin/bash
# Script pour démarrer le serveur Django sur le port 8000

# Activer l'environnement virtuel
cd "$(dirname "$0")"
source venv/bin/activate

echo "🚀 Démarrage du serveur Django sur le port 8000 (accessible depuis toutes les interfaces)..."
python manage.py runserver 0.0.0.0:8000

