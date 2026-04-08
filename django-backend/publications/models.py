from django.db import models
from django.utils import timezone
from django.core.exceptions import ValidationError
from utilisateurs.models import Utilisateur


class Domaine(models.Model):
    """Modèle pour gérer les domaines disponibles"""
    id = models.BigAutoField(primary_key=True)
    nom = models.CharField(max_length=255, unique=True, verbose_name="Nom du domaine")
    description = models.TextField(blank=True, null=True, verbose_name="Description")
    actif = models.BooleanField(default=True, verbose_name="Actif")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Date de création")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Date de modification")

    class Meta:
        db_table = 'domaines'
        ordering = ['nom']
        verbose_name = 'Domaine'
        verbose_name_plural = 'Domaines'

    def __str__(self):
        return self.nom


class Section(models.Model):
    """Modèle pour gérer les sections disponibles (Professionnelle, Locale, etc.)"""
    id = models.BigAutoField(primary_key=True)
    nom = models.CharField(max_length=255, unique=True, verbose_name="Nom de la section")
    description = models.TextField(blank=True, null=True, verbose_name="Description")
    actif = models.BooleanField(default=True, verbose_name="Actif")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Date de création")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Date de modification")

    class Meta:
        db_table = 'publication_sections'
        ordering = ['nom']
        verbose_name = 'Section'
        verbose_name_plural = 'Sections'

    def __str__(self):
        return self.nom


class Publication(models.Model):
    id = models.BigAutoField(primary_key=True)
    titre = models.CharField(max_length=500)
    contenu_texte = models.TextField()
    # Ancien champ générique de contact (conservé pour compatibilité éventuelle)
    contact = models.CharField(max_length=255, blank=True, null=True)
    # Liens de contact supplémentaires
    lien_email = models.EmailField(
        blank=True,
        null=True,
        verbose_name="Lien email"
    )
    lien_site_web = models.URLField(
        blank=True,
        null=True,
        verbose_name="Lien site web"
    )
    lien_whatsapp = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        verbose_name="Lien WhatsApp"
    )
    section = models.CharField(max_length=100)
    
    # Champs pour filtrage
    niveau = models.CharField(max_length=100, blank=True, null=True)  # BAC, BEPC, LICENCE
    domaine = models.CharField(max_length=1000, blank=True, null=True)  # Informatique, Comptabilité
    localite = models.CharField(max_length=100, blank=True, null=True)  # Ouagadougou, Bobo
    sexe = models.CharField(max_length=10, blank=True, null=True)  # M, F ou Tout
    
    # Fichiers
    image = models.CharField(max_length=500, blank=True, null=True)  # URL de l'image
    pdf = models.CharField(max_length=500, blank=True, null=True)  # URL du PDF

    # Section "Postuler" – au moins un de ces moyens doit être renseigné
    telephone_postuler = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name="Téléphone de contact"
    )
    whatsapp_postuler = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        verbose_name="Lien WhatsApp"
    )
    email_postuler = models.EmailField(
        blank=True,
        null=True,
        verbose_name="Email de contact"
    )
    depot_physique_postuler = models.TextField(
        blank=True,
        null=True,
        verbose_name="Adresse de dépôt physique"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    date_limite = models.DateTimeField(blank=True, null=True)
    
    auteur = models.ForeignKey(
        Utilisateur,
        on_delete=models.CASCADE,
        related_name='publications'
    )

    class Meta:
        db_table = 'publications'
        ordering = ['-created_at']

    def __str__(self):
        return self.titre
    
    def is_expired(self):
        """Vérifie si la publication est expirée"""
        if self.date_limite is None:
            return False
        return timezone.now() > self.date_limite

    def clean(self):
        """
        S'assure qu'au moins un des moyens de la section 'Postuler'
        est renseigné (téléphone, WhatsApp, email ou dépôt physique).
        """
        super().clean()

        if not any([
            self.telephone_postuler,
            self.whatsapp_postuler,
            self.email_postuler,
            self.depot_physique_postuler,
        ]):
            raise ValidationError(
                "Vous devez renseigner au moins un moyen de postulation "
                "(téléphone, lien WhatsApp, email ou dépôt physique)."
            )


class PublicationImage(models.Model):
    """Modèle pour gérer les images multiples d'une publication"""
    id = models.BigAutoField(primary_key=True)
    publication = models.ForeignKey(
        Publication,
        on_delete=models.CASCADE,
        related_name='images_supplementaires'
    )
    image = models.CharField(max_length=500, verbose_name="URL de l'image")
    ordre = models.PositiveIntegerField(default=0, verbose_name="Ordre d'affichage")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Date d'ajout")

    class Meta:
        db_table = 'publication_images'
        ordering = ['ordre', 'created_at']
        verbose_name = 'Image de publication'
        verbose_name_plural = 'Images de publication'

    def __str__(self):
        return f"Image {self.ordre} - {self.publication.titre}"


class Favori(models.Model):
    """Modèle pour gérer les publications favorites des utilisateurs"""
    id = models.BigAutoField(primary_key=True)
    utilisateur = models.ForeignKey(
        Utilisateur,
        on_delete=models.CASCADE,
        related_name='favoris'
    )
    publication = models.ForeignKey(
        Publication,
        on_delete=models.CASCADE,
        related_name='favoris'
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Date d'ajout")

    class Meta:
        db_table = 'favoris'
        unique_together = ('utilisateur', 'publication')  # Un utilisateur ne peut ajouter une publication qu'une seule fois
        ordering = ['-created_at']
        verbose_name = 'Favori'
        verbose_name_plural = 'Favoris'

    def __str__(self):
        return f"{self.utilisateur} - {self.publication.titre}"
