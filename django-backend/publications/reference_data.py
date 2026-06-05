"""Listes de référence partagées (domaines par défaut, etc.)."""

DEFAULT_DOMAINES = [
    ('INFORMATIQUE', 'Informatique, développement, réseaux'),
    ('FINANCE COMPTABILITÉ', 'Finance, comptabilité, audit'),
    ('ELECTRICITÉ', 'Installations et maintenance électrique'),
    ('ELECTRONIQUE', 'Électronique et systèmes embarqués'),
    ('DROIT', 'Juridique et conseil legal'),
    ('COMMERCE VENTE', 'Commerce, vente et distribution'),
    ('MARKETING COMMUNICATION', 'Marketing, communication et publicité'),
    ('RESSOURCES HUMAINES', 'Recrutement et gestion du personnel'),
    ('LOGISTIQUE TRANSPORT', 'Logistique, supply chain et transport'),
    ('BÂTIMENT CONSTRUCTION', 'BTP, construction et travaux publics'),
    ('SANTÉ', 'Santé, médical et paramédical'),
    ('ÉDUCATION ENSEIGNEMENT', 'Éducation, formation et enseignement'),
    ('AGRICULTURE ÉLEVAGE', 'Agriculture, élevage et agroalimentaire'),
    ('HÔTELLERIE RESTAURATION', 'Hôtellerie, restauration et tourisme'),
    ('ADMINISTRATION', 'Administration, secrétariat et gestion'),
]

DEFAULT_DOMAINE_NAMES = [nom for nom, _ in DEFAULT_DOMAINES]
