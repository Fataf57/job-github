import os
from django.core.management.base import BaseCommand
from django.utils import timezone
from publications.models import Publication
from django.conf import settings


class Command(BaseCommand):
    help = 'Supprime les publications expirées et leurs fichiers associés'

    def handle(self, *args, **options):
        now = timezone.now()
        expired_publications = Publication.objects.filter(
            date_limite__isnull=False,
            date_limite__lte=now
        )
        
        count = expired_publications.count()
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS('Aucune publication expirée à supprimer'))
            return
        
        self.stdout.write(f'Suppression de {count} publication(s) expirée(s)...')
        
        # Chemins de stockage
        images_root = os.path.join(settings.MEDIA_ROOT, 'publications', 'images')
        videos_root = os.path.join(settings.MEDIA_ROOT, 'publications', 'videos')
        docs_root = os.path.join(settings.MEDIA_ROOT, 'publications', 'docs')
        
        deleted_count = 0
        
        for publication in expired_publications:
            try:
                # Supprimer les fichiers associés
                if publication.image:
                    self._delete_file(publication.image, images_root, 'image')
                
                if publication.video:
                    self._delete_file(publication.video, videos_root, 'vidéo')
                
                if publication.pdf:
                    self._delete_file(publication.pdf, docs_root, 'PDF')
                
                # Supprimer la publication
                publication.delete()
                deleted_count += 1
                
                self.stdout.write(
                    self.style.SUCCESS(
                        f'✓ Publication supprimée: ID {publication.id} - {publication.titre}'
                    )
                )
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(
                        f'✗ Erreur lors de la suppression de la publication {publication.id}: {e}'
                    )
                )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\n✅ {deleted_count} publication(s) expirée(s) supprimée(s) avec succès'
            )
        )
    
    def _delete_file(self, file_url, root_path, file_type):
        """Supprime un fichier si l'URL correspond à un fichier stocké localement"""
        if not file_url:
            return
        
        try:
            # Extraire le nom du fichier depuis l'URL
            # Format: /api/publications/images/filename.jpg
            filename = file_url.split('/')[-1]
            if not filename:
                return
            
            file_path = os.path.join(root_path, filename)
            
            # Vérifier que le fichier est bien dans le dossier racine (sécurité)
            if not os.path.abspath(file_path).startswith(os.path.abspath(root_path)):
                self.stdout.write(
                    self.style.WARNING(
                        f'⚠️ Tentative de suppression d\'un fichier en dehors du dossier autorisé: {file_path}'
                    )
                )
                return
            
            # Supprimer le fichier s'il existe
            if os.path.exists(file_path):
                os.remove(file_path)
                self.stdout.write(f'  🗑️ Fichier {file_type} supprimé: {filename}')
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(
                    f'❌ Erreur lors de la suppression du fichier {file_type}: {file_url} - {e}'
                )
            )

