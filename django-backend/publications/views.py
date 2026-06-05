import os
from django.conf import settings
from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
from django.db import models
from django.http import FileResponse, Http404
from django.utils import timezone
from django.utils.text import slugify
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Publication, Domaine, Section, Favori, PublicationImage
from .serializers import PublicationSerializer
from .filters import (
    queryset_non_expirees,
    parse_filter_params,
    filtrer_publications,
)
from .reference_data import DEFAULT_DOMAINE_NAMES
from utilisateurs.models import Utilisateur
from datetime import datetime


# Listes de référence pour les publications (logique métier côté backend)
# Les domaines sont maintenant récupérés depuis la base de données

LOCALITES = [
    'OUAGA',
    'BOBO',
    'KOUDOU',
]

SEXE_OPTIONS = [
    'Tous',
    'Homme',
    'Femme',
]


# Chemins de stockage organisés
PUBLICATIONS_ROOT = os.path.join(settings.MEDIA_ROOT, 'publications')
IMAGES_ROOT = os.path.join(PUBLICATIONS_ROOT, 'images')
DOCS_ROOT = os.path.join(PUBLICATIONS_ROOT, 'docs')

# Créer les dossiers s'ils n'existent pas
os.makedirs(IMAGES_ROOT, exist_ok=True)
os.makedirs(DOCS_ROOT, exist_ok=True)


def paginate_list(request, items):
    """Paginates a list/queryset and returns a Response avec métadonnées."""
    try:
        page = int(request.GET.get('page', 1))
    except (ValueError, TypeError):
        page = 1
    try:
        page_size = int(request.GET.get('pageSize', 20))
        if page_size < 1 or page_size > 100:
            page_size = 20
    except (ValueError, TypeError):
        page_size = 20

    paginator = Paginator(items, page_size)
    try:
        page_obj = paginator.page(page)
    except EmptyPage:
        page_obj = paginator.page(paginator.num_pages)
    except PageNotAnInteger:
        page_obj = paginator.page(1)

    serializer = PublicationSerializer(list(page_obj.object_list), many=True)
    return Response({
        'count': paginator.count,
        'totalPages': paginator.num_pages,
        'currentPage': page_obj.number,
        'pageSize': page_size,
        'hasNext': page_obj.has_next(),
        'hasPrevious': page_obj.has_previous(),
        'results': serializer.data,
    })


def generate_file_name(original_filename):
    """Génère un nom de fichier unique en conservant l'extension."""
    timestamp = str(int(timezone.now().timestamp() * 1000))
    if original_filename:
        base, ext = os.path.splitext(original_filename)
        clean_base = slugify(base.replace(' ', '_')) or 'file'
        ext = ext.lower() if ext else ''
        return f"{timestamp}_{clean_base}{ext}"
    return f"{timestamp}_file.pdf"


def save_file(uploaded_file, root_path, file_type):
    """Sauvegarde un fichier et retourne l'URL"""
    if not uploaded_file:
        return None
    
    filename = generate_file_name(uploaded_file.name)
    file_path = os.path.join(root_path, filename)
    
    with open(file_path, 'wb+') as destination:
        for chunk in uploaded_file.chunks():
            destination.write(chunk)
    
    # Retourner l'URL relative
    if file_type == 'image':
        return f"/api/publications/images/{filename}"
    elif file_type == 'pdf':
        return f"/api/publications/docs/{filename}"
    return None


@api_view(['POST'])
def create_publication(request):
    """Créer une publication avec fichiers"""
    try:
        # Récupérer les données du formulaire
        titre = request.POST.get('titre')
        contenu_texte = request.POST.get('contenuTexte')
        auteur_id = request.POST.get('auteurId')
        contact = request.POST.get('contact')
        section = request.POST.get('section')
        niveau = request.POST.get('niveau', '')
        # Gérer les domaines (peut être une liste ou une chaîne)
        domaines = request.POST.getlist('domaines[]') or request.POST.getlist('domaines')
        if not domaines:
            domaine = request.POST.get('domaine', '')
        else:
            domaine = ', '.join(domaines)
        localite = request.POST.get('localite', '')
        sexe = request.POST.get('sexe', '')
        date_limite_str = request.POST.get('dateLimite', '')
        # Section Postuler
        telephone_postuler = request.POST.get('telephonePostuler') or request.POST.get('telephone_postuler')
        whatsapp_postuler = request.POST.get('whatsappPostuler') or request.POST.get('whatsapp_postuler')
        email_postuler = request.POST.get('emailPostuler') or request.POST.get('email_postuler')
        depot_physique_postuler = request.POST.get('depotPhysiquePostuler') or request.POST.get('depot_physique_postuler')
        # Liens de contact supplémentaires
        lien_email = request.POST.get('lienEmail') or request.POST.get('lien_email')
        lien_site_web = request.POST.get('lienSiteWeb') or request.POST.get('lien_site_web')
        lien_whatsapp = request.POST.get('lienWhatsapp') or request.POST.get('lien_whatsapp')
        
        # Récupérer les fichiers
        image = request.FILES.get('image')
        images_multiples = request.FILES.getlist('images[]') or request.FILES.getlist('images')
        pdf = request.FILES.get('pdf')
        
        # Vérifier l'auteur
        try:
            auteur = Utilisateur.objects.get(id=auteur_id)
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': f'Utilisateur non trouvé avec l\'ID: {auteur_id}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Créer la publication
        publication = Publication(
            titre=titre,
            contenu_texte=contenu_texte,
            contact=contact if contact else None,
            section=section,
            niveau=niveau if niveau else None,
            domaine=domaine if domaine else None,
            localite=localite if localite else None,
            sexe=sexe if sexe else None,
            auteur=auteur,
            telephone_postuler=telephone_postuler or None,
            whatsapp_postuler=whatsapp_postuler or None,
            email_postuler=email_postuler or None,
            depot_physique_postuler=depot_physique_postuler or None,
            lien_email=lien_email or None,
            lien_site_web=lien_site_web or None,
            lien_whatsapp=lien_whatsapp or None,
        )
        
        # Gérer la date limite
        if date_limite_str:
            try:
                # Essayer différents formats
                try:
                    date_limite = datetime.fromisoformat(date_limite_str.replace('Z', '+00:00'))
                except:
                    date_limite = datetime.strptime(date_limite_str, '%Y-%m-%dT%H:%M:%S')
                publication.date_limite = timezone.make_aware(date_limite)
            except Exception as e:
                print(f"Erreur lors du parsing de la date limite: {e}")
        
        # Sauvegarder les fichiers
        images_supp_a_enregistrer = images_multiples
        if image:
            publication.image = save_file(image, IMAGES_ROOT, 'image')
        elif images_multiples:
            # Première image comme image principale pour la rétrocompatibilité
            publication.image = save_file(images_multiples[0], IMAGES_ROOT, 'image')
            # Éviter le doublon : la première image est déjà utilisée en image principale
            images_supp_a_enregistrer = images_multiples[1:]

        if pdf:
            publication.pdf = save_file(pdf, DOCS_ROOT, 'pdf')

        publication.save()

        # Sauvegarder les images supplémentaires
        if images_supp_a_enregistrer:
            for i, img_file in enumerate(images_supp_a_enregistrer):
                img_url = save_file(img_file, IMAGES_ROOT, 'image')
                if img_url:
                    PublicationImage.objects.create(
                        publication=publication,
                        image=img_url,
                        ordre=i
                    )

        serializer = PublicationSerializer(publication)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        print(f"Erreur lors de la création de la publication: {e}")
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
def get_all_publications(request):
    """
    Publications non expirées, filtrage métier complet (domaines Pro, sexe, localité).
    Paramètres GET : utilisateur_id, localite (ou ville), page, pageSize.
    """
    utilisateur, localite = parse_filter_params(request)
    publications = queryset_non_expirees()
    publications = filtrer_publications(publications, utilisateur=utilisateur, localite=localite)
    return paginate_list(request, publications)


@api_view(['GET'])
def get_publication_by_id(request, id):
    """Récupérer une publication par ID"""
    try:
        publication = Publication.objects.select_related('auteur').get(id=id)
        
        # Vérifier si la publication est expirée
        if publication.is_expired():
            return Response(
                {'error': f'Publication expirée avec l\'ID: {id}'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = PublicationSerializer(publication)
        return Response(serializer.data)
    except Publication.DoesNotExist:
        return Response(
            {'error': f'Publication non trouvée avec l\'ID: {id}'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['PUT'])
def update_publication(request, id):
    """Mettre à jour une publication"""
    try:
        publication = Publication.objects.get(id=id)
        
        # Mettre à jour les champs
        publication.titre = request.POST.get('titre', publication.titre)
        publication.contenu_texte = request.POST.get('contenuTexte', publication.contenu_texte)
        contact = request.POST.get('contact')
        publication.contact = contact if contact else None
        publication.section = request.POST.get('section', publication.section)
        publication.niveau = request.POST.get('niveau', publication.niveau) or None
        publication.domaine = request.POST.get('domaine', publication.domaine) or None
        publication.localite = request.POST.get('localite', publication.localite) or None
        publication.sexe = request.POST.get('sexe', publication.sexe) or None
        # Section Postuler
        telephone_postuler = request.POST.get('telephonePostuler') or request.POST.get('telephone_postuler')
        whatsapp_postuler = request.POST.get('whatsappPostuler') or request.POST.get('whatsapp_postuler')
        email_postuler = request.POST.get('emailPostuler') or request.POST.get('email_postuler')
        depot_physique_postuler = request.POST.get('depotPhysiquePostuler') or request.POST.get('depot_physique_postuler')
        # Liens de contact supplémentaires
        lien_email = request.POST.get('lienEmail') or request.POST.get('lien_email')
        lien_site_web = request.POST.get('lienSiteWeb') or request.POST.get('lien_site_web')
        lien_whatsapp = request.POST.get('lienWhatsapp') or request.POST.get('lien_whatsapp')

        if telephone_postuler is not None:
            publication.telephone_postuler = telephone_postuler or None
        if whatsapp_postuler is not None:
            publication.whatsapp_postuler = whatsapp_postuler or None
        if email_postuler is not None:
            publication.email_postuler = email_postuler or None
        if depot_physique_postuler is not None:
            publication.depot_physique_postuler = depot_physique_postuler or None
        if lien_email is not None:
            publication.lien_email = lien_email or None
        if lien_site_web is not None:
            publication.lien_site_web = lien_site_web or None
        if lien_whatsapp is not None:
            publication.lien_whatsapp = lien_whatsapp or None
        
        # Gérer la date limite
        date_limite_str = request.POST.get('dateLimite', '')
        if date_limite_str:
            try:
                date_limite = datetime.fromisoformat(date_limite_str.replace('Z', '+00:00'))
                publication.date_limite = timezone.make_aware(date_limite)
            except:
                try:
                    date_limite = datetime.strptime(date_limite_str, '%Y-%m-%dT%H:%M:%S')
                    publication.date_limite = timezone.make_aware(date_limite)
                except:
                    pass
        
        # Gérer les fichiers (remplacement si fournis)
        if 'image' in request.FILES:
            # Supprimer l'ancienne image si elle existe
            if publication.image:
                old_path = publication.image.replace('/api/publications/images/', '')
                old_file = os.path.join(IMAGES_ROOT, old_path)
                if os.path.exists(old_file):
                    os.remove(old_file)
            publication.image = save_file(request.FILES['image'], IMAGES_ROOT, 'image')
        
        if 'pdf' in request.FILES:
            if publication.pdf:
                old_path = publication.pdf.replace('/api/publications/docs/', '')
                old_file = os.path.join(DOCS_ROOT, old_path)
                if os.path.exists(old_file):
                    os.remove(old_file)
            publication.pdf = save_file(request.FILES['pdf'], DOCS_ROOT, 'pdf')
        
        publication.save()
        
        serializer = PublicationSerializer(publication)
        return Response(serializer.data)
        
    except Publication.DoesNotExist:
        return Response(
            {'error': 'Publication non trouvée'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
def delete_publication(request, id):
    """Supprimer une publication"""
    try:
        publication = Publication.objects.get(id=id)
        
        # Supprimer les fichiers associés
        if publication.image:
            old_path = publication.image.replace('/api/publications/images/', '')
            old_file = os.path.join(IMAGES_ROOT, old_path)
            if os.path.exists(old_file):
                os.remove(old_file)

        # Supprimer les images supplémentaires
        for pub_img in publication.images_supplementaires.all():
            old_path = pub_img.image.replace('/api/publications/images/', '')
            old_file = os.path.join(IMAGES_ROOT, old_path)
            if os.path.exists(old_file):
                os.remove(old_file)

        if publication.pdf:
            old_path = publication.pdf.replace('/api/publications/docs/', '')
            old_file = os.path.join(DOCS_ROOT, old_path)
            if os.path.exists(old_file):
                os.remove(old_file)
        
        publication.delete()
        return Response(status=status.HTTP_200_OK)
        
    except Publication.DoesNotExist:
        return Response(
            {'error': 'Publication non trouvée'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['GET'])
def get_publications_by_section(request, section):
    """
    Publications d'une section, filtrage métier complet côté serveur.
    Paramètres GET : utilisateur_id, localite (ou ville), page, pageSize.
    """
    utilisateur, localite = parse_filter_params(request)
    publications = queryset_non_expirees().filter(section=section)
    publications = filtrer_publications(publications, utilisateur=utilisateur, localite=localite)
    return paginate_list(request, publications)


@api_view(['GET'])
def get_publications_by_utilisateur(request, utilisateur_id):
    """Publications d'un auteur (non expirées), filtrage visibilité optionnel."""
    utilisateur, localite = parse_filter_params(request, utilisateur_id_fallback=utilisateur_id)
    publications = queryset_non_expirees().filter(auteur_id=utilisateur_id)
    publications = filtrer_publications(publications, utilisateur=utilisateur, localite=localite)
    return paginate_list(request, publications)


@api_view(['DELETE'])
def delete_all_publications(request):
    """Supprimer toutes les publications"""
    count_before = Publication.objects.count()
    
    # Supprimer tous les fichiers associés
    for publication in Publication.objects.all():
        if publication.image:
            old_path = publication.image.replace('/api/publications/images/', '')
            old_file = os.path.join(IMAGES_ROOT, old_path)
            if os.path.exists(old_file):
                os.remove(old_file)
        if publication.pdf:
            old_path = publication.pdf.replace('/api/publications/docs/', '')
            old_file = os.path.join(DOCS_ROOT, old_path)
            if os.path.exists(old_file):
                os.remove(old_file)
    
    Publication.objects.all().delete()
    count_after = Publication.objects.count()
    
    return Response({
        'message': 'Toutes les publications ont été supprimées',
        'deletedCount': count_before,
        'remainingCount': count_after
    })


# Endpoints pour servir les fichiers
@api_view(['GET'])
def serve_image(request, filename):
    """Servir une image"""
    file_path = os.path.join(IMAGES_ROOT, filename)
    if os.path.exists(file_path):
        import mimetypes
        content_type, _ = mimetypes.guess_type(file_path)
        if not content_type:
            content_type = 'image/jpeg'
        return FileResponse(open(file_path, 'rb'), content_type=content_type)
    raise Http404


@api_view(['GET'])
def serve_pdf(request, filename):
    """Servir un PDF"""
    file_path = os.path.join(DOCS_ROOT, filename)
    if os.path.exists(file_path):
        return FileResponse(open(file_path, 'rb'), content_type='application/pdf')
    raise Http404


@api_view(['GET'])
def get_reference_lists(request):
    """Récupérer les listes de référence pour les publications (domaines, localités, sections, etc.)"""
    # Récupérer les domaines actifs depuis la base de données
    domaines_actifs = Domaine.objects.filter(actif=True).order_by('nom').values_list('nom', flat=True)
    domaines_list = list(domaines_actifs) if domaines_actifs.exists() else DEFAULT_DOMAINE_NAMES
    # Récupérer les sections actives depuis la base de données (exclure "Favoris" qui n'est pas une section normale)
    sections_actives = Section.objects.filter(actif=True).exclude(nom='Favoris').values_list('nom', flat=True)
    sections_list = list(sections_actives) if sections_actives.exists() else []
    
    return Response({
        'domaines': domaines_list,
        'localites': LOCALITES,
        'sections': sections_list,
        'sexeOptions': SEXE_OPTIONS,
    })


@api_view(['POST'])
def add_favori(request, publication_id):
    """Ajouter une publication aux favoris d'un utilisateur"""
    utilisateur_id = request.POST.get('utilisateur_id') or request.data.get('utilisateur_id')
    if not utilisateur_id:
        return Response(
            {'error': 'utilisateur_id est requis'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        utilisateur = Utilisateur.objects.get(id=utilisateur_id)
        publication = Publication.objects.get(id=publication_id)
        
        # Vérifier si le favori existe déjà
        favori, created = Favori.objects.get_or_create(
            utilisateur=utilisateur,
            publication=publication
        )
        
        if created:
            return Response(
                {'message': 'Publication ajoutée aux favoris', 'is_favori': True},
                status=status.HTTP_201_CREATED
            )
        else:
            return Response(
                {'message': 'Publication déjà dans les favoris', 'is_favori': True},
                status=status.HTTP_200_OK
            )
    except Utilisateur.DoesNotExist:
        return Response(
            {'error': 'Utilisateur non trouvé'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Publication.DoesNotExist:
        return Response(
            {'error': 'Publication non trouvée'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['DELETE'])
def remove_favori(request, publication_id):
    """Retirer une publication des favoris d'un utilisateur"""
    utilisateur_id = request.GET.get('utilisateur_id') or request.data.get('utilisateur_id')
    if not utilisateur_id:
        return Response(
            {'error': 'utilisateur_id est requis'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        utilisateur = Utilisateur.objects.get(id=utilisateur_id)
        publication = Publication.objects.get(id=publication_id)
        
        favori = Favori.objects.filter(
            utilisateur=utilisateur,
            publication=publication
        ).first()
        
        if favori:
            favori.delete()
            return Response(
                {'message': 'Publication retirée des favoris', 'is_favori': False},
                status=status.HTTP_200_OK
            )
        else:
            return Response(
                {'message': 'Publication n\'était pas dans les favoris', 'is_favori': False},
                status=status.HTTP_200_OK
            )
    except Utilisateur.DoesNotExist:
        return Response(
            {'error': 'Utilisateur non trouvé'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Publication.DoesNotExist:
        return Response(
            {'error': 'Publication non trouvée'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['GET'])
def check_favori(request, publication_id):
    """Vérifier si une publication est dans les favoris d'un utilisateur"""
    utilisateur_id = request.GET.get('utilisateur_id')
    if not utilisateur_id:
        return Response(
            {'error': 'utilisateur_id est requis'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        utilisateur = Utilisateur.objects.get(id=utilisateur_id)
        publication = Publication.objects.get(id=publication_id)
        
        is_favori = Favori.objects.filter(
            utilisateur=utilisateur,
            publication=publication
        ).exists()
        
        return Response({'is_favori': is_favori})
    except Utilisateur.DoesNotExist:
        return Response(
            {'error': 'Utilisateur non trouvé'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Publication.DoesNotExist:
        return Response(
            {'error': 'Publication non trouvée'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['GET'])
def get_favoris(request, utilisateur_id):
    """Favoris non expirés, filtrage métier complet (sexe, localité, domaines Pro)."""
    try:
        utilisateur = Utilisateur.objects.get(id=utilisateur_id)
        _, localite = parse_filter_params(request, utilisateur_id_fallback=utilisateur_id)

        from django.db.models import Q

        now = timezone.now()
        favoris = Favori.objects.filter(
            utilisateur=utilisateur
        ).filter(
            Q(publication__date_limite__isnull=True) | Q(publication__date_limite__gt=now)
        ).select_related('publication', 'publication__auteur').order_by('-created_at')

        publications = [favori.publication for favori in favoris]
        publications = filtrer_publications(
            publications, utilisateur=utilisateur, localite=localite
        )
        return paginate_list(request, publications)
    except Utilisateur.DoesNotExist:
        return Response(
            {'error': 'Utilisateur non trouvé'},
            status=status.HTTP_404_NOT_FOUND
        )
