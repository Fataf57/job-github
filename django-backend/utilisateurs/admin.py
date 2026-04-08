from django.contrib import admin
from .models import Utilisateur, Role


@admin.register(Utilisateur)
class UtilisateurAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom_complet', 'telephone', 'email', 'role', 'actif', 'sexe', 'localite', 'domaines_list')
    list_filter = ('role', 'actif', 'sexe', 'niveau', 'localite')
    search_fields = ('nom', 'prenom', 'telephone', 'email', 'domaine')
    readonly_fields = ('id', 'domaines_list')
    fieldsets = (
        ('Informations personnelles', {
            'fields': ('nom', 'prenom', 'email', 'telephone', 'photo_profil', 'sexe')
        }),
        ('Authentification', {
            'fields': ('mot_de_passe', 'role', 'actif')
        }),
        ('Filtres de recherche', {
            'fields': ('niveau', 'domaine', 'domaines_list', 'localite')
        }),
    )
    ordering = ('-id',)
    
    def nom_complet(self, obj):
        """Afficher le nom complet"""
        return f"{obj.prenom} {obj.nom}".strip() or f"Utilisateur {obj.id}"
    nom_complet.short_description = 'Nom complet'
    
    def domaines_list(self, obj):
        """Afficher les domaines comme une liste lisible"""
        if obj.domaine:
            domaines = [d.strip() for d in obj.domaine.split(',') if d.strip()]
            return ', '.join(domaines) if domaines else '-'
        return '-'
    domaines_list.short_description = 'Domaines'
