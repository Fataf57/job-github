from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('publications', '0007_remove_publication_video'),
    ]

    operations = [
        migrations.AlterField(
            model_name='publication',
            name='contact',
            field=models.CharField(blank=True, max_length=255, null=True),
        ),
    ]
