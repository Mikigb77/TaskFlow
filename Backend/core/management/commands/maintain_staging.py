from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken
from core.email_delivery import deliver_email
from core.models import EmailDelivery, RuntimeState


class Command(BaseCommand):
    help = "Retry pending transactional email and remove expired operational state. Never deletes tasks or attachments."

    def handle(self, *args, **options):
        now = timezone.now()
        pending = EmailDelivery.objects.filter(state="pending", next_attempt_at__lte=now, expires_at__gt=now).order_by("created_at")
        processed = 0
        for key in list(pending.values_list("pk", flat=True)[:50]):
            deliver_email(key)
            processed += 1
        RuntimeState.objects.filter(expires_at__lt=now - timedelta(days=1)).delete()
        EmailDelivery.objects.filter(expires_at__lte=now).delete()
        OutstandingToken.objects.filter(expires_at__lt=now).delete()
        self.stdout.write(f"Maintenance complete; {processed} pending messages processed.")
