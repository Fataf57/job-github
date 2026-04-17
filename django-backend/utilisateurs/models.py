from django.db import models


class Role(models.TextChoices):
    ADMINISTRATEUR = 'ADMINISTRATEUR', 'Administrateur'
    CHERCHEUR = 'CHERCHEUR', 'Chercheur'
    RECRUTEUR = 'RECRUTEUR', 'Recruteur'


class Utilisateur(models.Model):
    id = models.BigAutoField(primary_key=True)
    nom = models.CharField(max_length=255, blank=True, null=True)
    prenom = models.CharField(max_length=255, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    telephone = models.CharField(max_length=20, unique=True)
    photo_profil = models.CharField(max_length=500, blank=True, null=True)
    mot_de_passe = models.CharField(max_length=255)
    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.CHERCHEUR
    )
    actif = models.BooleanField(default=True)

    # Champs chercheur
    niveau = models.CharField(max_length=100, blank=True, null=True)
    domaine = models.CharField(max_length=500, blank=True, null=True)
    localite = models.CharField(max_length=100, blank=True, null=True)
    sexe = models.CharField(max_length=10, blank=True, null=True)

    # Champs recruteur / entreprise
    nom_entreprise = models.CharField(max_length=255, blank=True, null=True)
    secteur_activite = models.CharField(max_length=255, blank=True, null=True)
    description_entreprise = models.TextField(blank=True, null=True)
    adresse_entreprise = models.CharField(max_length=500, blank=True, null=True)
    site_web = models.CharField(max_length=255, blank=True, null=True)
    rccm = models.CharField(max_length=100, blank=True, null=True)
    nif = models.CharField(max_length=100, blank=True, null=True)
    logo_entreprise = models.CharField(max_length=500, blank=True, null=True)

    # Vérification email
    email_verifie = models.BooleanField(default=False)
    code_verification = models.CharField(max_length=6, blank=True, null=True)
    code_expiration = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'utilisateurs'
        ordering = ['-id']

    def __str__(self):
        if self.role == Role.RECRUTEUR and self.nom_entreprise:
            return f"{self.nom_entreprise} ({self.telephone})"
        return f"{self.prenom} {self.nom} ({self.telephone})"
