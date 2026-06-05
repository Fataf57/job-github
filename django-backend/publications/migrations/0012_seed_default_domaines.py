from django.db import migrations


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


def seed_domaines(apps, schema_editor):
    Domaine = apps.get_model('publications', 'Domaine')
    for nom, description in DEFAULT_DOMAINES:
        Domaine.objects.get_or_create(
            nom=nom,
            defaults={'description': description, 'actif': True},
        )


def unseed_domaines(apps, schema_editor):
    Domaine = apps.get_model('publications', 'Domaine')
    noms = [nom for nom, _ in DEFAULT_DOMAINES]
    Domaine.objects.filter(nom__in=noms).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('publications', '0011_seed_default_sections'),
    ]

    operations = [
        migrations.RunPython(seed_domaines, unseed_domaines),
    ]
