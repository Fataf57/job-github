from django.contrib import admin
from .models import Publication, Domaine, Section, Favori


@admin.register(Domaine)
class DomaineAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom', 'actif', 'created_at', 'updated_at')
    list_filter = ('actif', 'created_at')
    search_fields = ('nom', 'description')
    readonly_fields = ('id', 'created_at', 'updated_at')
    fieldsets = (
        ('Informations', {
            'fields': ('nom', 'description', 'actif')
        }),
        ('Dates', {
            'fields': ('created_at', 'updated_at')
        }),
    )
    ordering = ('nom',)


@admin.register(Section)
class SectionAdmin(admin.ModelAdmin):
    list_display = ('id', 'nom', 'actif', 'created_at', 'updated_at')
    list_filter = ('actif', 'created_at')
    search_fields = ('nom', 'description')
    readonly_fields = ('id', 'created_at', 'updated_at')
    fieldsets = (
        ('Informations', {
            'fields': ('nom', 'description', 'actif')
        }),
        ('Dates', {
            'fields': ('created_at', 'updated_at')
        }),
    )
    ordering = ('nom',)


@admin.register(Publication)
class PublicationAdmin(admin.ModelAdmin):
    list_display = ('id', 'titre', 'section', 'auteur', 'domaines_list', 'localite', 'created_at', 'date_limite', 'is_expired')
    list_filter = ('section', 'niveau', 'localite', 'sexe', 'created_at', 'date_limite')
    search_fields = ('titre', 'contenu_texte', 'contact', 'auteur__nom', 'auteur__prenom', 'auteur__telephone', 'domaine')
    readonly_fields = ('id', 'created_at', 'domaines_list')
    fieldsets = (
        ('Informations générales', {
            'fields': ('titre', 'contenu_texte', 'contact', 'section', 'auteur')
        }),
        ('Filtres', {
            'fields': ('niveau', 'domaine', 'domaines_list', 'localite', 'sexe')
        }),
        ('Section Postuler', {
            'fields': (
                'telephone_postuler',
                'whatsapp_postuler',
                'email_postuler',
                'depot_physique_postuler',
            )
        }),
        ('Fichiers', {
            'fields': ('image', 'pdf')
        }),
        ('Dates', {
            'fields': ('created_at', 'date_limite')
        }),
    )
    ordering = ('-created_at',)
    date_hierarchy = 'created_at'
    
    def domaines_list(self, obj):
        """Afficher les domaines comme une liste lisible"""
        if obj.domaine:
            domaines = [d.strip() for d in obj.domaine.split(',') if d.strip()]
            return ', '.join(domaines) if domaines else '-'
        return '-'
    domaines_list.short_description = 'Domaines'


@admin.register(Favori)
class FavoriAdmin(admin.ModelAdmin):
    list_display = ('id', 'utilisateur', 'publication', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('utilisateur__nom', 'utilisateur__prenom', 'utilisateur__telephone', 'publication__titre')
    readonly_fields = ('id', 'created_at')
    ordering = ('-created_at',)
    date_hierarchy = 'created_at'
