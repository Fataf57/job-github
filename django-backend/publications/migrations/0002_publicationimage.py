import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('publications', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='PublicationImage',
            fields=[
                ('id', models.BigAutoField(primary_key=True, serialize=False)),
                ('image', models.CharField(max_length=500, verbose_name="URL de l'image")),
                ('ordre', models.PositiveIntegerField(default=0, verbose_name="Ordre d'affichage")),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name="Date d'ajout")),
                ('publication', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='images_supplementaires',
                    to='publications.publication'
                )),
            ],
            options={
                'verbose_name': 'Image de publication',
                'verbose_name_plural': 'Images de publication',
                'db_table': 'publication_images',
                'ordering': ['ordre', 'created_at'],
            },
        ),
    ]
