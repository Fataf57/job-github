import random
from django.core.mail import send_mail
from django.utils import timezone
from datetime import timedelta
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Utilisateur
from .serializers import UtilisateurSerializer
from .phone_utils import normalize_telephone


def _generer_code():
    """Génère un code de vérification à 6 chiffres."""
    return str(random.randint(100000, 999999))


def _envoyer_code_email(email, code, prenom=''):
    """Envoie le code de vérification par email."""
    sujet = "Votre code de vérification"
    message = (
        f"Bonjour{' ' + prenom if prenom else ''},\n\n"
        f"Votre code de vérification est : {code}\n\n"
        f"Ce code est valable 15 minutes.\n\n"
        f"Si vous n'avez pas créé de compte, ignorez ce message."
    )
    send_mail(sujet, message, None, [email], fail_silently=False)


def _notifier_code_telephone(telephone, code):
    """Notification du code par SMS (en dev : affichage console)."""
    print(f"[VERIFICATION SMS] {telephone} → code: {code}")


def _trouver_utilisateur_pour_verification(email='', telephone=''):
    if email:
        return Utilisateur.objects.get(email=email)
    if telephone:
        return Utilisateur.objects.get(telephone=telephone)
    raise Utilisateur.DoesNotExist


@api_view(['POST'])
def create_utilisateur(request):
    """Créer un utilisateur et envoyer un code de vérification obligatoire."""
    serializer = UtilisateurSerializer(data=request.data)
    if serializer.is_valid():
        utilisateur = serializer.save()

        code = _generer_code()
        utilisateur.code_verification = code
        utilisateur.code_expiration = timezone.now() + timedelta(minutes=15)
        utilisateur.email_verifie = False
        utilisateur.save(
            update_fields=['code_verification', 'code_expiration', 'email_verifie']
        )

        email = utilisateur.email
        telephone = utilisateur.telephone
        if email:
            try:
                _envoyer_code_email(email, code, utilisateur.prenom or '')
            except Exception:
                print(f"[VERIFICATION EMAIL] {email} → code: {code}")
        elif telephone:
            _notifier_code_telephone(telephone, code)

        return Response(
            {'message': 'Compte créé. Vérifiez le code reçu pour activer votre compte.'},
            status=status.HTTP_201_CREATED,
        )
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
def login(request):
    """Authentification par téléphone et mot de passe"""
    telephone = normalize_telephone(request.data.get('telephone') or '')
    mot_de_passe = request.data.get('motDePasse')
    
    if not telephone or not mot_de_passe:
        return Response(
            'Champs manquants', 
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        utilisateur = Utilisateur.objects.get(
            telephone=telephone,
            mot_de_passe=mot_de_passe
        )
        if not utilisateur.email_verifie:
            return Response(
                {'message': 'Compte non vérifié. Entrez le code reçu lors de l\'inscription.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = UtilisateurSerializer(utilisateur)
        return Response(serializer.data, status=status.HTTP_200_OK)
    except Utilisateur.DoesNotExist:
        return Response(
            'Identifiants invalides', 
            status=status.HTTP_401_UNAUTHORIZED
        )


@api_view(['POST'])
def verify_email(request):
    """Vérifier le code reçu par email ou téléphone."""
    email = request.data.get('email', '').strip()
    telephone = normalize_telephone(request.data.get('telephone') or '')
    code = request.data.get('code', '').strip()

    if not code or (not email and not telephone):
        return Response(
            {'message': 'Code et email ou téléphone requis.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        utilisateur = _trouver_utilisateur_pour_verification(email=email, telephone=telephone)
    except Utilisateur.DoesNotExist:
        return Response(
            {'message': 'Aucun compte associé à ces identifiants.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if utilisateur.email_verifie:
        return Response({'message': 'Email déjà vérifié.'}, status=status.HTTP_200_OK)

    if not utilisateur.code_verification or utilisateur.code_verification != code:
        return Response({'message': 'Code incorrect.'}, status=status.HTTP_400_BAD_REQUEST)

    if utilisateur.code_expiration and timezone.now() > utilisateur.code_expiration:
        return Response({'message': 'Code expiré. Demandez un nouveau code.'}, status=status.HTTP_400_BAD_REQUEST)

    utilisateur.email_verifie = True
    utilisateur.code_verification = None
    utilisateur.code_expiration = None
    utilisateur.save(update_fields=['email_verifie', 'code_verification', 'code_expiration'])

    return Response({'message': 'Email vérifié avec succès !'}, status=status.HTTP_200_OK)


@api_view(['POST'])
def resend_verification(request):
    """Renvoyer un nouveau code de vérification."""
    email = request.data.get('email', '').strip()
    telephone = normalize_telephone(request.data.get('telephone') or '')

    if not email and not telephone:
        return Response(
            {'message': 'Email ou téléphone requis.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        utilisateur = _trouver_utilisateur_pour_verification(email=email, telephone=telephone)
    except Utilisateur.DoesNotExist:
        return Response(
            {'message': 'Aucun compte associé à ces identifiants.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if utilisateur.email_verifie:
        return Response({'message': 'Email déjà vérifié.'}, status=status.HTTP_200_OK)

    code = _generer_code()
    utilisateur.code_verification = code
    utilisateur.code_expiration = timezone.now() + timedelta(minutes=15)
    utilisateur.save(update_fields=['code_verification', 'code_expiration'])

    if utilisateur.email:
        try:
            _envoyer_code_email(utilisateur.email, code, utilisateur.prenom or '')
        except Exception:
            print(f"[VERIFICATION EMAIL] {utilisateur.email} → code: {code}")
    elif utilisateur.telephone:
        _notifier_code_telephone(utilisateur.telephone, code)

    return Response({'message': 'Nouveau code envoyé.'}, status=status.HTTP_200_OK)


@api_view(['GET'])
def get_all_utilisateurs(request):
    """Récupérer tous les utilisateurs"""
    utilisateurs = Utilisateur.objects.all()
    serializer = UtilisateurSerializer(utilisateurs, many=True)
    return Response(serializer.data)


@api_view(['GET', 'PUT'])
def get_utilisateur_by_id(request, id):
    """Récupérer ou mettre à jour un utilisateur par ID"""
    try:
        utilisateur = Utilisateur.objects.get(id=id)
        
        if request.method == 'PUT':
            # Convertir les champs camelCase en snake_case
            data = request.data.copy()
            if 'photoProfil' in data:
                data['photo_profil'] = data.pop('photoProfil')
            if 'motDePasse' in data:
                data['mot_de_passe'] = data.pop('motDePasse')
            
            serializer = UtilisateurSerializer(utilisateur, data=data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        else:
            # GET
            serializer = UtilisateurSerializer(utilisateur)
            return Response(serializer.data)
    except Utilisateur.DoesNotExist:
        return Response(
            'Utilisateur non trouvé', 
            status=status.HTTP_404_NOT_FOUND
        )


