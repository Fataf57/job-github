import json
from rest_framework import serializers
from .models import Utilisateur, Role


class DomaineNiveauSerializer(serializers.Serializer):
    """Serializer pour un domaine avec son niveau"""
    domaine = serializers.CharField()
    niveau = serializers.CharField(allow_blank=True, allow_null=True)


class UtilisateurSerializer(serializers.ModelSerializer):
    motDePasse = serializers.CharField(source='mot_de_passe', write_only=True, required=False)
    photoProfil = serializers.CharField(source='photo_profil', required=False, allow_blank=True, allow_null=True)
    domaines = serializers.ListField(
        child=DomaineNiveauSerializer(),
        required=False,
        allow_empty=True,
        write_only=True
    )
    
    class Meta:
        model = Utilisateur
        fields = [
            'id', 'nom', 'prenom', 'email', 'telephone', 'photoProfil',
            'motDePasse', 'role', 'actif', 'niveau', 'domaine', 'domaines',
            'localite', 'sexe'
        ]
        extra_kwargs = {
            'telephone': {'required': True},
        }
    
    def to_internal_value(self, data):
        """Convertir la liste de domaines avec niveaux en JSON"""
        if 'domaines' in data and isinstance(data['domaines'], list):
            data = data.copy()
            domaines_list = data.pop('domaines')
            domaines_with_niveau = []
            
            for item in domaines_list:
                if isinstance(item, dict):
                    # Valider avec le serializer
                    serializer = DomaineNiveauSerializer(data=item)
                    if serializer.is_valid():
                        domaines_with_niveau.append(serializer.validated_data)
                    else:
                        # Si validation échoue, prendre les valeurs brutes
                        domaines_with_niveau.append({
                            "domaine": item.get('domaine', ''),
                            "niveau": item.get('niveau')
                        })
                elif isinstance(item, str):
                    # Ancien format: juste le nom du domaine
                    domaines_with_niveau.append({"domaine": item, "niveau": None})
            
            # Convertir en JSON pour stockage
            data['domaine'] = json.dumps(domaines_with_niveau, ensure_ascii=False) if domaines_with_niveau else None
        return super().to_internal_value(data)
    
    def to_representation(self, instance):
        """Convertir les noms de champs en camelCase pour la réponse"""
        data = super().to_representation(instance)
        # Ne pas inclure motDePasse dans la réponse
        data.pop('motDePasse', None)
        
        # Convertir le domaine (JSON ou chaîne) en liste pour la réponse
        if instance.domaine:
            try:
                # Essayer de parser comme JSON
                domaines_data = json.loads(instance.domaine)
                if isinstance(domaines_data, list):
                    data['domaines'] = domaines_data
                else:
                    # Format ancien: chaîne séparée par des virgules
                    data['domaines'] = [
                        {"domaine": d.strip(), "niveau": None}
                        for d in instance.domaine.split(',') if d.strip()
                    ]
            except (json.JSONDecodeError, TypeError):
                # Format ancien: chaîne séparée par des virgules
                data['domaines'] = [
                    {"domaine": d.strip(), "niveau": None}
                    for d in instance.domaine.split(',') if d.strip()
                ]
        else:
            data['domaines'] = []
        return data

