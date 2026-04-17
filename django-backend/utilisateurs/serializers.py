import json
from rest_framework import serializers
from .models import Utilisateur, Role


class DomaineNiveauSerializer(serializers.Serializer):
    domaine = serializers.CharField()
    niveau = serializers.CharField(allow_blank=True, allow_null=True, required=False)


class UtilisateurSerializer(serializers.ModelSerializer):
    motDePasse = serializers.CharField(source='mot_de_passe', write_only=True, required=False)
    photoProfil = serializers.CharField(source='photo_profil', required=False, allow_blank=True, allow_null=True)
    domaines = serializers.ListField(
        child=DomaineNiveauSerializer(),
        required=False,
        allow_empty=True,
        write_only=True
    )
    # Champs recruteur en camelCase
    nomEntreprise = serializers.CharField(source='nom_entreprise', required=False, allow_blank=True, allow_null=True)
    secteurActivite = serializers.CharField(source='secteur_activite', required=False, allow_blank=True, allow_null=True)
    descriptionEntreprise = serializers.CharField(source='description_entreprise', required=False, allow_blank=True, allow_null=True)
    adresseEntreprise = serializers.CharField(source='adresse_entreprise', required=False, allow_blank=True, allow_null=True)
    siteWeb = serializers.CharField(source='site_web', required=False, allow_blank=True, allow_null=True)
    logoEntreprise = serializers.CharField(source='logo_entreprise', required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = Utilisateur
        fields = [
            'id', 'nom', 'prenom', 'email', 'telephone', 'photoProfil',
            'motDePasse', 'role', 'actif', 'niveau', 'domaine', 'domaines',
            'localite', 'sexe',
            'nomEntreprise', 'secteurActivite', 'descriptionEntreprise',
            'adresseEntreprise', 'siteWeb', 'rccm', 'nif', 'logoEntreprise',
        ]
        extra_kwargs = {
            'telephone': {'required': True},
            'nom': {'required': False, 'allow_blank': True, 'allow_null': True},
            'prenom': {'required': False, 'allow_blank': True, 'allow_null': True},
            'email': {'required': False, 'allow_blank': True, 'allow_null': True},
            'rccm': {'required': False, 'allow_blank': True, 'allow_null': True},
            'nif': {'required': False, 'allow_blank': True, 'allow_null': True},
        }

    def to_internal_value(self, data):
        if 'domaines' in data and isinstance(data['domaines'], list):
            data = data.copy()
            domaines_list = data.pop('domaines')
            domaines_with_niveau = []
            for item in domaines_list:
                if isinstance(item, dict):
                    s = DomaineNiveauSerializer(data=item)
                    if s.is_valid():
                        domaines_with_niveau.append(s.validated_data)
                    else:
                        domaines_with_niveau.append({'domaine': item.get('domaine', ''), 'niveau': item.get('niveau')})
                elif isinstance(item, str):
                    domaines_with_niveau.append({'domaine': item, 'niveau': None})
            data['domaine'] = json.dumps(domaines_with_niveau, ensure_ascii=False) if domaines_with_niveau else None
        return super().to_internal_value(data)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data.pop('motDePasse', None)
        if instance.domaine:
            try:
                parsed = json.loads(instance.domaine)
                data['domaines'] = parsed if isinstance(parsed, list) else [{'domaine': d.strip(), 'niveau': None} for d in instance.domaine.split(',') if d.strip()]
            except (json.JSONDecodeError, TypeError):
                data['domaines'] = [{'domaine': d.strip(), 'niveau': None} for d in instance.domaine.split(',') if d.strip()]
        else:
            data['domaines'] = []
        return data
