import logging
import random
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .email_service import email_is_configured, send_verification_code, uses_console_email
from .models import Utilisateur
from .phone_utils import normalize_telephone
from .serializers import UtilisateurSerializer

logger = logging.getLogger(__name__)

TEST_VERIFICATION_CODE = '123456'


def _generer_code():
    return str(random.randint(100000, 999999))


def _log_verification_code(canal, identifiant, code):
    print(f"[VERIFICATION {canal}] {identifiant} → code: {code}")


def _verification_payload(message, code=None):
    payload = {'message': message}
    if code and uses_console_email():
        payload['verification_code'] = code
    return payload


def _test_code_autorise(code: str) -> bool:
    return settings.DEBUG and code == TEST_VERIFICATION_CODE


def _envoyer_code(utilisateur, code):
    if utilisateur.email:
        send_verification_code(utilisateur.email, code, utilisateur.prenom or '')
        _log_verification_code('EMAIL', utilisateur.email, code)
        return

    if utilisateur.telephone:
        _log_verification_code('SMS', utilisateur.telephone, code)


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

        try:
            _envoyer_code(utilisateur, code)
        except Exception as exc:
            logger.exception('Envoi du code de verification echoue')
            utilisateur.delete()
            return Response(
                {
                    'message': (
                        'Impossible d\'envoyer l\'email de vérification. '
                        'Vérifiez votre adresse email ou réessayez plus tard.'
                    ),
                    'detail': str(exc) if settings.DEBUG else None,
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        message = (
            'Compte créé. Un code de vérification a été envoyé à votre adresse email.'
            if utilisateur.email and email_is_configured()
            else 'Compte créé. Vérifiez le code reçu pour activer votre compte.'
        )
        return Response(
            _verification_payload(message, code),
            status=status.HTTP_201_CREATED,
        )
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
def login(request):
    """Authentification par telephone et mot de passe"""
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
    """Verifier le code recu par email ou telephone."""
    email = request.data.get('email', '').strip()
    telephone = normalize_telephone(request.data.get('telephone') or '')
    code = request.data.get('code', '').strip()

    if not code or (not email and not telephone):
        return Response(
            {'message': 'Code et email ou téléphone requis.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        if email:
            utilisateur = Utilisateur.objects.get(email=email)
        else:
            utilisateur = Utilisateur.objects.get(telephone=telephone)
    except Utilisateur.DoesNotExist:
        return Response(
            {'message': 'Aucun compte associé à ces identifiants.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if utilisateur.email_verifie:
        return Response({'message': 'Email déjà vérifié.'}, status=status.HTTP_200_OK)

    code_valide = _test_code_autorise(code) or utilisateur.code_verification == code
    if not code_valide:
        return Response({'message': 'Code incorrect.'}, status=status.HTTP_400_BAD_REQUEST)

    if (
        not _test_code_autorise(code)
        and utilisateur.code_expiration
        and timezone.now() > utilisateur.code_expiration
    ):
        return Response(
            {'message': 'Code expiré. Demandez un nouveau code.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    utilisateur.email_verifie = True
    utilisateur.code_verification = None
    utilisateur.code_expiration = None
    utilisateur.save(update_fields=['email_verifie', 'code_verification', 'code_expiration'])

    return Response({'message': 'Email vérifié avec succès !'}, status=status.HTTP_200_OK)


@api_view(['POST'])
def resend_verification(request):
    """Renvoyer un nouveau code de verification."""
    email = request.data.get('email', '').strip()
    telephone = normalize_telephone(request.data.get('telephone') or '')

    if not email and not telephone:
        return Response(
            {'message': 'Email ou téléphone requis.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        if email:
            utilisateur = Utilisateur.objects.get(email=email)
        else:
            utilisateur = Utilisateur.objects.get(telephone=telephone)
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

    try:
        _envoyer_code(utilisateur, code)
    except Exception as exc:
        logger.exception('Renvoi du code de verification echoue')
        return Response(
            {
                'message': 'Impossible d\'envoyer l\'email. Réessayez dans quelques instants.',
                'detail': str(exc) if settings.DEBUG else None,
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    message = (
        'Un nouveau code a été envoyé à votre adresse email.'
        if utilisateur.email and email_is_configured()
        else 'Nouveau code envoyé.'
    )
    return Response(
        _verification_payload(message, code),
        status=status.HTTP_200_OK,
    )


@api_view(['GET'])
def get_all_utilisateurs(request):
    """Recuperer tous les utilisateurs"""
    utilisateurs = Utilisateur.objects.all()
    serializer = UtilisateurSerializer(utilisateurs, many=True)
    return Response(serializer.data)


@api_view(['GET', 'PUT'])
def get_utilisateur_by_id(request, id):
    """Recuperer ou mettre a jour un utilisateur par ID"""
    try:
        utilisateur = Utilisateur.objects.get(id=id)

        if request.method == 'PUT':
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

        serializer = UtilisateurSerializer(utilisateur)
        return Response(serializer.data)
    except Utilisateur.DoesNotExist:
        return Response(
            'Utilisateur non trouvé',
            status=status.HTTP_404_NOT_FOUND
        )
