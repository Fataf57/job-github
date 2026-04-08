from django.db import models


class Role(models.TextChoices):
    ADMINISTRATEUR = 'ADMINISTRATEUR', 'Administrateur'
    UTILISATEUR = 'UTILISATEUR', 'Utilisateur'


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
        default=Role.UTILISATEUR
    )
    actif = models.BooleanField(default=True)

    # Champs de filtrage
    niveau = models.CharField(max_length=100, blank=True, null=True)  # BAC, BEPC, LICENCE
    domaine = models.CharField(max_length=100, blank=True, null=True)  # Informatique, Comptabilité
    localite = models.CharField(max_length=100, blank=True, null=True)  # Ouagadougou, Bobo
    sexe = models.CharField(max_length=10, blank=True, null=True)  # M, F ou Tout

    # Vérification email
    email_verifie = models.BooleanField(default=False)
    code_verification = models.CharField(max_length=6, blank=True, null=True)
    code_expiration = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'utilisateurs'
        ordering = ['-id']

    def __str__(self):
        return f"{self.prenom} {self.nom} ({self.telephone})"
