from django.db import migrations


def seed_sections(apps, schema_editor):
    Section = apps.get_model('publications', 'Section')
    defaults = [
        ('Professionnelle', 'Offres et opportunités professionnelles'),
        ('Locale', 'Offres et informations locales'),
    ]
    for nom, description in defaults:
        Section.objects.get_or_create(
            nom=nom,
            defaults={'description': description, 'actif': True},
        )


def unseed_sections(apps, schema_editor):
    Section = apps.get_model('publications', 'Section')
    Section.objects.filter(nom__in=['Professionnelle', 'Locale']).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('publications', '0010_domaine_max_length_1000'),
    ]

    operations = [
        migrations.RunPython(seed_sections, unseed_sections),
    ]
