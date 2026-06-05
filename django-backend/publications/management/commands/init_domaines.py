"""
Commande Django pour initialiser les domaines dans la base de données.
Usage: python manage.py init_domaines
"""
from django.core.management.base import BaseCommand
from publications.models import Domaine
from publications.reference_data import DEFAULT_DOMAINES


class Command(BaseCommand):
    help = 'Initialise les domaines par défaut dans la base de données'

    def handle(self, *args, **options):
        created_count = 0
        existing_count = 0

        for nom, description in DEFAULT_DOMAINES:
            _, created = Domaine.objects.get_or_create(
                nom=nom,
                defaults={
                    'actif': True,
                    'description': description,
                },
            )
            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(f'✅ Domaine créé: {nom}'))
            else:
                existing_count += 1
                self.stdout.write(self.style.WARNING(f'⚠️  Domaine déjà existant: {nom}'))

        self.stdout.write(
            self.style.SUCCESS(
                f'\n✅ Terminé! {created_count} domaines créés, {existing_count} déjà existants.'
            )
        )
