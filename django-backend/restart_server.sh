#!/bin/bash
# Script pour redémarrer le serveur Django sur toutes les interfaces

echo "🛑 Arrêt des processus Django existants..."
pkill -f "manage.py runserver" || echo "Aucun processus à arrêter"

sleep 2

echo "🚀 Démarrage du serveur Django sur 0.0.0.0:8000..."
cd "$(dirname "$0")"
python3 manage.py runserver 0.0.0.0:8000

