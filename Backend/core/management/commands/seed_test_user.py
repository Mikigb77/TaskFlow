from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.core.validators import validate_email

from core.email_verification import mark_verified
from core.models import User


class Command(BaseCommand):
    help = "Create the configured local test account once, preserving existing accounts and tasks."

    def handle(self, *args, **options):
        if not settings.LOCAL_TEST_ACCOUNT_ENABLED:
            return
        email = settings.LOCAL_TEST_ACCOUNT_EMAIL.strip().casefold()
        password = settings.LOCAL_TEST_ACCOUNT_PASSWORD
        try:
            validate_email(email)
            validate_password(password, User(email=email))
        except ValidationError as error:
            raise CommandError("Invalid local test account configuration: " + "; ".join(error.messages))
        user, created = User.objects.get_or_create(email=email, defaults={
            "password": make_password(password),
            "first_name": "Local tester",
            "timezone": settings.DEFAULT_TIME_ZONE,
            "is_staff": False,
            "is_superuser": False,
            # The developer login uses the normal sign-in, which needs a confirmed address.
            "email_verified": True,
        })
        if created:
            self.stdout.write(self.style.SUCCESS(f"Created local test account: {email}"))
        else:
            self.stdout.write(f"Kept existing test account and its tasks: {email}")
        if user.is_staff or user.is_superuser or not user.is_active or not user.check_password(password):
            self.stdout.write(self.style.WARNING("Existing account differs from the test configuration; left unchanged."))
        elif not user.email_verified:
            # Signed up in the app with this address, and the emailed code never entered.
            mark_verified(user)
            self.stdout.write("Confirmed the test account's email address.")
