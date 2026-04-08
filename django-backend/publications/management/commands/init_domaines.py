"""
Commande Django pour initialiser les domaines dans la base de données
Usage: python manage.py init_domaines
"""
from django.core.management.base import BaseCommand
from publications.models import Domaine


class Command(BaseCommand):
    help = 'Initialise les domaines dans la base de données'

    def handle(self, *args, **options):
        domaines_initiaux = [
            'INFORMATIQUE',
            'FINANCE COMPTABILITÉ',
            'ELECTRICITÉ',
            'ELECTRONIQUE',
            'DROIT',
        ]
        
        created_count = 0
        existing_count = 0
        
        for nom_domaine in domaines_initiaux:
            domaine, created = Domaine.objects.get_or_create(
                nom=nom_domaine,
                defaults={
                    'actif': True,
                    'description': f'Domaine {nom_domaine}'
                }
            )
            if created:
                created_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f'✅ Domaine créé: {nom_domaine}')
                )
            else:
                existing_count += 1
                self.stdout.write(
                    self.style.WARNING(f'⚠️  Domaine déjà existant: {nom_domaine}')
                )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\n✅ Terminé! {created_count} domaines créés, {existing_count} déjà existants.'
            )
        )

