from django.contrib import admin
from .models import Utilisateur, Role


@admin.register(Utilisateur)
class UtilisateurAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom_complet', 'telephone', 'email', 'role', 'actif', 'localite')
    list_filter = ('role', 'actif', 'sexe', 'niveau', 'localite', 'secteur_activite')
    search_fields = ('nom', 'prenom', 'telephone', 'email', 'nom_entreprise')
    readonly_fields = ('id',)
    fieldsets = (
        ('Informations personnelles (Chercheur)', {
            'fields': ('nom', 'prenom', 'email', 'telephone', 'photo_profil', 'sexe')
        }),
        ('Authentification', {
            'fields': ('mot_de_passe', 'role', 'actif', 'email_verifie')
        }),
        ('Profil Chercheur', {
            'fields': ('niveau', 'domaine', 'localite'),
            'classes': ('collapse',),
        }),
        ('Profil Recruteur / Entreprise', {
            'fields': ('nom_entreprise', 'secteur_activite', 'description_entreprise',
                       'adresse_entreprise', 'site_web', 'rccm', 'nif', 'logo_entreprise'),
            'classes': ('collapse',),
        }),
    )
    ordering = ('-id',)

    def nom_complet(self, obj):
        if obj.role == Role.RECRUTEUR and obj.nom_entreprise:
            return obj.nom_entreprise
        return f"{obj.prenom} {obj.nom}".strip() or f"Utilisateur {obj.id}"
    nom_complet.short_description = 'Nom / Entreprise'
