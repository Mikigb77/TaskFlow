import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0017_runtimestate_emaildelivery'),
    ]

    operations = [
        migrations.CreateModel(
            name='FreeDictation',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('period', models.CharField(max_length=7)),
                ('capture_id', models.UUIDField(null=True)),
                ('digest', models.CharField(max_length=64)),
                ('counted', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField()),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='free_dictations', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'indexes': [models.Index(fields=['user', 'period'], name='free_dictation_month')],
            },
        ),
    ]
