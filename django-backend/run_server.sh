#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
echo "🚀 Démarrage du serveur Django sur 0.0.0.0:8000..."
echo "📡 Accessible depuis: http://10.53.20.188:8000"
python manage.py runserver 0.0.0.0:8000

