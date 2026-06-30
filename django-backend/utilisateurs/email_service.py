import logging

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


def uses_console_email() -> bool:
    return 'console' in settings.EMAIL_BACKEND.lower()


def email_is_configured() -> bool:
    return not uses_console_email()


def send_verification_code(email: str, code: str, prenom: str = '') -> None:
    """Envoie le code de vérification par email (SendGrid SMTP en production)."""
    greeting = f'Bonjour {prenom},' if prenom else 'Bonjour,'
    subject = 'Votre code de vérification FASO JOB'
    text_body = (
        f'{greeting}\n\n'
        f'Votre code de vérification est : {code}\n\n'
        f'Ce code est valable 15 minutes.\n\n'
        f'Si vous n\'avez pas créé de compte FASO JOB, ignorez ce message.\n\n'
        f'— L\'équipe FASO JOB'
    )
    html_body = f"""
    <p>{greeting}</p>
    <p>Votre code de vérification FASO JOB est :</p>
    <p style="font-size:28px;font-weight:bold;letter-spacing:4px;">{code}</p>
    <p>Ce code est valable <strong>15 minutes</strong>.</p>
    <p>Si vous n'avez pas créé de compte, ignorez ce message.</p>
    <p>— L'équipe FASO JOB</p>
    """

    send_mail(
        subject=subject,
        message=text_body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[email],
        html_message=html_body,
        fail_silently=False,
    )
    logger.info('Verification email sent to %s', email)
