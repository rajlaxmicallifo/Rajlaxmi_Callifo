from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('calls', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='calllog',
            name='recording_uploaded_at',
            field=models.DateTimeField(blank=True, null=True, verbose_name='Recording upload timestamp'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='call_status',
            field=models.CharField(choices=[('registered', 'Registered in Bitrix24'), ('completed', 'Completed'), ('failed', 'Failed'), ('recording_uploaded', 'Recording Uploaded')], default='registered', max_length=20, verbose_name='Call synchronization status'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='bitrix_user_id',
            field=models.IntegerField(blank=True, null=True, verbose_name='Bitrix24 User ID used for this call'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='bitrix_registered_at',
            field=models.DateTimeField(blank=True, null=True, verbose_name='Bitrix24 registration timestamp'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='bitrix_finished_at',
            field=models.DateTimeField(blank=True, null=True, verbose_name='Bitrix24 finish timestamp'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='start_time',
            field=models.DateTimeField(default=django.utils.timezone.now, verbose_name='Call start time'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='end_time',
            field=models.DateTimeField(blank=True, null=True, verbose_name='Call end time'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='is_answered',
            field=models.BooleanField(default=False, verbose_name='Call was answered'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='recording_duration',
            field=models.IntegerField(default=0, verbose_name='Actual recording duration in seconds'),
        ),
        migrations.AddField(
            model_name='calllog',
            name='error_message',
            field=models.TextField(blank=True, null=True, verbose_name='Error details if sync failed'),
        ),
    ]