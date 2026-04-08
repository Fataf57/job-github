from rest_framework import serializers
from .models import Publication, PublicationImage
from utilisateurs.serializers import UtilisateurSerializer
from utilisateurs.models import Utilisateur


class PublicationImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PublicationImage
        fields = ['id', 'image', 'ordre']


class PublicationSerializer(serializers.ModelSerializer):
    auteur = UtilisateurSerializer(read_only=True)
    auteurId = serializers.PrimaryKeyRelatedField(
        source='auteur',
        queryset=Utilisateur.objects.all(),
        write_only=True,
        required=False
    )
    contenuTexte = serializers.CharField(source='contenu_texte')
    createdAt = serializers.DateTimeField(source='created_at', read_only=True)
    dateLimite = serializers.DateTimeField(source='date_limite', required=False, allow_null=True)
    telephonePostuler = serializers.CharField(
        source='telephone_postuler',
        required=False,
        allow_blank=True,
        allow_null=True
    )
    whatsappPostuler = serializers.CharField(
        source='whatsapp_postuler',
        required=False,
        allow_blank=True,
        allow_null=True
    )
    emailPostuler = serializers.EmailField(
        source='email_postuler',
        required=False,
        allow_null=True
    )
    depotPhysiquePostuler = serializers.CharField(
        source='depot_physique_postuler',
        required=False,
        allow_blank=True,
        allow_null=True
    )
    lienEmail = serializers.EmailField(
        source='lien_email',
        required=False,
        allow_null=True,
        allow_blank=True
    )
    lienSiteWeb = serializers.URLField(
        source='lien_site_web',
        required=False,
        allow_null=True,
        allow_blank=True
    )
    lienWhatsapp = serializers.CharField(
        source='lien_whatsapp',
        required=False,
        allow_null=True,
        allow_blank=True
    )
    domaines = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        allow_empty=True,
        write_only=True
    )
    images_supplementaires = PublicationImageSerializer(many=True, read_only=True)

    class Meta:
        model = Publication
        fields = [
            'id', 'titre', 'contenuTexte', 'contact', 'section',
            'niveau', 'domaine', 'domaines', 'localite', 'sexe',
            'image', 'images_supplementaires', 'pdf',
            'telephonePostuler', 'whatsappPostuler', 'emailPostuler', 'depotPhysiquePostuler',
            'lienEmail', 'lienSiteWeb', 'lienWhatsapp',
            'createdAt', 'dateLimite', 'auteur', 'auteurId'
        ]
        read_only_fields = ['createdAt']
    
    def to_internal_value(self, data):
        """Convertir la liste de domaines en chaîne séparée par des virgules"""
        if 'domaines' in data and isinstance(data['domaines'], list):
            # Convertir la liste en chaîne séparée par des virgules
            data = data.copy()
            data['domaine'] = ', '.join(data.pop('domaines'))
        return super().to_internal_value(data)
    
    def to_representation(self, instance):
        """Convertir le domaine (chaîne) en liste pour la réponse, et construire la liste unifiée d'images"""
        data = super().to_representation(instance)
        # Convertir le domaine (chaîne) en liste pour la réponse
        if instance.domaine:
            data['domaines'] = [d.strip() for d in instance.domaine.split(',') if d.strip()]
        else:
            data['domaines'] = []
        # Construire la liste unifiée d'images : images_supplementaires + image principale si absente
        images_supp = data.get('images_supplementaires', [])
        images_urls = [img['image'] for img in images_supp]
        if not images_urls and instance.image:
            images_urls = [instance.image]
        elif instance.image and instance.image not in images_urls:
            images_urls = [instance.image] + images_urls
        data['images'] = images_urls
        return data

