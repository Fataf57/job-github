"""
Filtrage métier des publications — source unique de vérité côté backend.

Périmètre MVP (filtres de visibilité actifs) :
  1. Expiration   — date_limite
  2. Section      — Professionnelle, Locale, etc.
  3. Domaine      — section Professionnelle uniquement (noms de domaines)
  4. Ville        — paramètre localite / ville
  5. Sexe         — profil utilisateur vs cible de la publication

Hors périmètre MVP (non utilisés pour filtrer l'affichage) :
  - niveau (profil ou publication)
  - expérience
  - autres règles avancées
"""
import json
from django.db import models
from django.utils import timezone

from .models import Publication
from utilisateurs.models import Utilisateur


def queryset_non_expirees():
    """Publications non expirées, triées par date de création."""
    now = timezone.now()
    return (
        Publication.objects.filter(
            models.Q(date_limite__isnull=True) | models.Q(date_limite__gt=now)
        )
        .select_related('auteur')
        .order_by('-created_at')
    )


def parse_filter_params(request, utilisateur_id_fallback=None):
    """
    Extrait utilisateur et localité depuis la requête GET.
    Accepte localite ou ville comme nom de paramètre.
    """
    utilisateur = None
    raw_id = request.GET.get('utilisateur_id') or utilisateur_id_fallback
    if raw_id:
        try:
            utilisateur = Utilisateur.objects.get(id=int(raw_id))
        except (Utilisateur.DoesNotExist, ValueError, TypeError):
            pass

    localite = (request.GET.get('localite') or request.GET.get('ville') or '').strip()
    if not localite or localite.upper() == 'TOUS':
        localite = None

    return utilisateur, localite


def extraire_noms_domaines(champ):
    """
    Extrait uniquement les noms de domaines (ignore le niveau).
    Accepte : liste CSV, JSON [{domaine, niveau}, ...], ou texte brut.
    """
    if not champ or not str(champ).strip():
        return []

    raw = str(champ).strip()
    noms = []

    if raw.startswith('['):
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                for item in parsed:
                    if isinstance(item, dict):
                        nom = (item.get('domaine') or '').strip()
                        if nom:
                            noms.append(nom.lower())
                    elif isinstance(item, str) and item.strip():
                        noms.append(item.strip().lower())
                return noms
        except (json.JSONDecodeError, TypeError):
            pass

    for part in raw.split(','):
        part = part.strip()
        if part:
            noms.append(part.lower())
    return noms


def domaines_se_chevauchent(domaines_utilisateur, domaines_publication):
    """Au moins un domaine en commun ; vide côté user ou pub = visible (MVP : domaine seul)."""
    domaines_user = extraire_noms_domaines(domaines_utilisateur)
    domaines_pub = extraire_noms_domaines(domaines_publication)

    if not domaines_user:
        return True
    if not domaines_pub:
        return True

    return bool(set(domaines_user) & set(domaines_pub))


def _normaliser_sexe(value):
    if not value or not str(value).strip():
        return None
    return str(value).strip().lower()


def _utilisateur_est_homme(sexe):
    if not sexe:
        return False
    return sexe in ('homme', 'masculin', 'm') or 'homme' in sexe


def _utilisateur_est_femme(sexe):
    if not sexe:
        return False
    return sexe in ('femme', 'féminin', 'feminin', 'f') or 'femme' in sexe


def publication_visible_par_sexe(publication, utilisateur=None):
    """
    - Pub sans sexe ou « Tous » → visible.
    - Utilisateur sans sexe → pas de filtre.
    - Sinon : pub alignée sur le sexe utilisateur.
    """
    user_sexe = _normaliser_sexe(utilisateur.sexe if utilisateur else None)
    if not user_sexe:
        return True

    pub_sexe = _normaliser_sexe(publication.sexe)
    if not pub_sexe or pub_sexe in ('tous', 'tout'):
        return True

    if _utilisateur_est_homme(user_sexe):
        return (
            pub_sexe in ('homme', 'masculin', 'm')
            or 'homme' in pub_sexe
        )
    if _utilisateur_est_femme(user_sexe):
        return (
            pub_sexe in ('femme', 'féminin', 'feminin', 'f')
            or 'femme' in pub_sexe
        )
    return True


def _normaliser_localite(value):
    if not value or not str(value).strip():
        return None
    return str(value).strip().upper()


def _localites_equivalentes(a, b):
    """Ouaga = Ouagadougou."""
    ouaga = {'OUAGA', 'OUAGADOUGOU'}
    if a in ouaga and b in ouaga:
        return True
    return a == b or a in b or b in a


def publication_visible_par_localite(publication, localite_filtre):
    """Sans filtre ville → visible. Pub sans localité → visible partout."""
    filtre = _normaliser_localite(localite_filtre)
    if not filtre:
        return True

    pub_loc = _normaliser_localite(publication.localite)
    if not pub_loc:
        return True

    if filtre in ('OUAGA', 'OUAGADOUGOU'):
        return 'OUAGA' in pub_loc or pub_loc == 'OUAGADOUGOU'

    return _localites_equivalentes(filtre, pub_loc) or filtre in pub_loc or pub_loc in filtre


def publication_est_visible(publication, utilisateur=None, localite=None):
    """Pipeline MVP : domaines (Pro) → sexe → ville."""
    if publication.section == 'Professionnelle' and utilisateur is not None:
        if not domaines_se_chevauchent(utilisateur.domaine, publication.domaine):
            return False

    if not publication_visible_par_sexe(publication, utilisateur):
        return False

    if not publication_visible_par_localite(publication, localite):
        return False

    return True


def filtrer_publications(publications, utilisateur=None, localite=None):
    """Retourne la liste des publications visibles selon les règles métier."""
    return [
        pub for pub in publications
        if publication_est_visible(pub, utilisateur=utilisateur, localite=localite)
    ]
