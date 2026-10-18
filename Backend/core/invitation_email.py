"""The invitation email: who invited the person, to which project or group, one button and the code.

In English, Spanish or Catalan. The outbox stores only the plain text (EmailDelivery.body)
and clears it once the email is sent, code included, so nothing else may hold the code.
The designed HTML is therefore rebuilt from that text when the email goes out
(email_delivery.email_html): it always says exactly what the text says, and whatever the
outbox appends to the text, such as its automated-email footer, becomes the HTML's footer.
"""
import re
import string
from functools import lru_cache

from django.conf import settings
from django.utils.html import escape

from .models import User

WEBSITE = "https://taskflow.garbar.tech/"
KINDS = ("list", "group")  # A list is a project.

COPY = {
    "en": {
        "subject": {"list": "You’re invited to a project in TaskFlow", "group": "You’re invited to a group in TaskFlow"},
        "headline": {"list": "{sender} invited you to join the project “{name}” in TaskFlow.",
                     "group": "{sender} invited you to join the group “{name}” in TaskFlow."},
        "what": {"list": "You’ll see its tasks, notes and files.",
                 "group": "You’ll see all its projects, with their tasks, notes and files."},
        "button": "Review the invitation",
        "code_member": "Or open TaskFlow signed in as {email}, tap the invitation and paste this code:",
        "code_new": "Once you have the app, create your account with {email}, tap the invitation and paste this code:",
        "new_question": "New to TaskFlow?",
        "new": "The app is coming soon to Google Play. Until then, you can see what it does at {website}",
        "tester": "If you’re a staging tester, use the private build supplied by the owner and create an account "
                  "with this email address.",
        "fine_print": "The invitation expires in 7 days, and you join only if you accept it. "
                      "If you weren’t expecting it, you can ignore this email.",
        "eyebrow": "Invitation",
        "someone": "Someone",
    },
    "es": {
        "subject": {"list": "Te han invitado a un proyecto en TaskFlow", "group": "Te han invitado a un grupo en TaskFlow"},
        "headline": {"list": "{sender} te invita a unirte al proyecto «{name}» en TaskFlow.",
                     "group": "{sender} te invita a unirte al grupo «{name}» en TaskFlow."},
        "what": {"list": "Verás sus tareas, notas y archivos.",
                 "group": "Verás todos sus proyectos, con sus tareas, notas y archivos."},
        "button": "Revisar la invitación",
        "code_member": "O abre TaskFlow con la sesión iniciada como {email}, toca la invitación y pega este código:",
        "code_new": "Cuando tengas la app, crea tu cuenta con {email}, toca la invitación y pega este código:",
        "new_question": "¿Aún no usas TaskFlow?",
        "new": "La app llegará pronto a Google Play. Mientras tanto, puedes ver lo que hace en {website}",
        "tester": "Si pruebas la versión de staging, usa la versión privada que te ha dado el responsable de TaskFlow "
                  "y crea una cuenta con esta dirección de correo.",
        "fine_print": "La invitación caduca en 7 días y solo te unes si la aceptas. "
                      "Si no la esperabas, puedes ignorar este correo.",
        "eyebrow": "Invitación",
        "someone": "Alguien",
    },
    "ca": {
        "subject": {"list": "T’han convidat a un projecte a TaskFlow", "group": "T’han convidat a un grup a TaskFlow"},
        "headline": {"list": "{sender} et convida a unir-te al projecte «{name}» a TaskFlow.",
                     "group": "{sender} et convida a unir-te al grup «{name}» a TaskFlow."},
        "what": {"list": "En veuràs les tasques, les notes i els fitxers.",
                 "group": "En veuràs tots els projectes, amb les tasques, les notes i els fitxers."},
        "button": "Revisa la invitació",
        "code_member": "O obre TaskFlow amb la sessió iniciada com a {email}, toca la invitació i enganxa-hi aquest codi:",
        "code_new": "Quan tinguis l’app, crea el teu compte amb {email}, toca la invitació i enganxa-hi aquest codi:",
        "new_question": "Encara no fas servir TaskFlow?",
        "new": "L’app arribarà aviat a Google Play. Mentrestant, pots veure què fa a {website}",
        "tester": "Si proves la versió de staging, fes servir la versió privada que t’ha donat el responsable de TaskFlow "
                  "i crea un compte amb aquesta adreça de correu.",
        "fine_print": "La invitació caduca d’aquí a 7 dies i només t’hi uneixes si l’acceptes. "
                      "Si no l’esperaves, pots ignorar aquest correu.",
        "eyebrow": "Invitació",
        "someone": "Algú",
    },
}
# Emails queued before this design started the same way.
LEGACY_MARKER = " invited you to join "


def language_code(value):
    """"en", "es" or "ca" from "es", "ca-ES", "en_GB"…; None when missing or unknown."""
    if isinstance(value, str):
        primary = value.strip().replace("_", "-").split("-")[0].lower()
        if primary in COPY:
            return primary
    return None


def preferred_language(header):
    """The language an Accept-Language header prefers among English, Spanish and Catalan."""
    if not isinstance(header, str):
        return None
    choices = []
    for position, part in enumerate(header.split(",")[:20]):
        tag, _, parameters = part.partition(";")
        quality = 1.0
        for parameter in parameters.split(";"):
            key, _, value = parameter.partition("=")
            if key.strip().lower() == "q":
                try:
                    quality = float(value)
                except ValueError:
                    quality = 0.0
        code = language_code(tag)
        if code and quality > 0:
            choices.append((-quality, position, code))
    return min(choices)[2] if choices else None


def invitation_language(requested=None, accept_language=None):
    """The inviter's choice: the request's language, else its Accept-Language, else English."""
    return language_code(requested) or preferred_language(accept_language) or "en"


def _line(value):
    # Names are shown on one line, so nothing in them can pass for another part of the email.
    return " ".join(str(value).split())


def has_account(email):
    """Whether the invited address can already sign in to TaskFlow."""
    return User.objects.filter(email__iexact=email, is_active=True, email_verified=True).exists()


def _text(copy, kind, *, sender, name, link, email, code, new_user, staging):
    paragraphs = [copy["headline"][kind].format(sender=sender, name=name) + "\n" + copy["what"][kind],
                  copy["button"] + ":\n" + link]
    if new_user:
        new = copy["new_question"] + " " + copy["new"].format(website=WEBSITE)
        paragraphs.append(new + ("\n" + copy["tester"] if staging else ""))
        paragraphs.append(copy["code_new"].format(email=email) + "\n" + code)
    else:
        paragraphs.append(copy["code_member"].format(email=email) + "\n" + code)
    paragraphs.append(copy["fine_print"])
    return "\n\n".join(paragraphs)


def invitation_message(*, kind, sender, name, link, email, code, language=None):
    """(subject, plain-text body) for an invitation. The subject names nobody: unlike the
    body, the outbox keeps it after sending."""
    copy = COPY[language_code(language) or "en"]
    body = _text(copy, kind, sender=_line(sender), name=_line(name), link=link, email=_line(email), code=code,
                 new_user=not has_account(email), staging=settings.DEPLOYMENT_ENVIRONMENT == "staging")
    return copy["subject"][kind], body


def unsigned_invitation(body, senders):
    """The body with its sender replaced by «Someone» in its language, or None when it
    doesn't start with one of these senders."""
    for language, copy in COPY.items():
        markers = [template.split("{sender}", 1)[1].split("{name}", 1)[0] for template in copy["headline"].values()]
        if language == "en":
            markers.append(LEGACY_MARKER)
        for sender in senders:
            # As invitation_message wrote it, and as older emails did.
            for written in dict.fromkeys((_line(sender), sender)):
                if written and any(body.startswith(written + marker) for marker in markers):
                    return copy["someone"] + body[len(written):]
    return None


GROUPS = {"sender": r"(?P<sender>[^\n]+?)", "name": r"(?P<name>[^\n]+)", "link": r"(?P<link>https?://\S+)",
          "email": r"(?P<email>\S+)", "code": r"(?P<code>\S+)"}


@lru_cache(maxsize=None)
def _patterns():
    """One pattern per language, kind and variant, made from the same text as the email."""
    patterns = []
    for language, copy in COPY.items():
        for kind in KINDS:
            for new_user, staging in ((False, False), (True, False), (True, True)):
                marked = _text(copy, kind, new_user=new_user, staging=staging,
                               **{key: f"\x00{key}\x00" for key in GROUPS})
                pattern = re.escape(marked)
                for key, group in GROUPS.items():
                    pattern = pattern.replace(re.escape(f"\x00{key}\x00"), group)
                # Whatever the outbox appends after a blank line (its footer) is kept for the HTML.
                patterns.append((language, kind, new_user, staging,
                                 re.compile(pattern + r"(?:\n\n(?P<footer>(?s:.*)))?\Z")))
    return patterns


FONT = "font-family:system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;"
# The brand colours of templates/invitation.html. The muted grey is a little darker than the
# page's #66786f, so small text keeps a 4.5:1 contrast on the page background too.
PAGE, CARD, LINE, INK, MUTED, ACCENT = "#f6f8f3", "#ffffff", "#dfe7df", "#193d36", "#5d6e66", "#176d5c"
# Dark mode, for the clients that support it; the others invert the light colours themselves.
STYLE = """
:root{color-scheme:light dark;supported-color-schemes:light dark}
@media (prefers-color-scheme:dark){
.tf-page{background-color:#111a17!important}
.tf-card{background-color:#1a2521!important;border-color:#30423a!important}
.tf-ink{color:#eff6ef!important}
.tf-muted{color:#a5b5ac!important}
.tf-accent,.tf-link{color:#8bd5bb!important}
.tf-button{background-color:#8bd5bb!important}
.tf-button-link{color:#133b2e!important}
.tf-code{background-color:#111a17!important;border-color:#30423a!important;color:#eff6ef!important}
.tf-fine{color:#a5b5ac!important;border-color:#30423a!important}
}
[data-ogsc] .tf-ink{color:#eff6ef!important}
[data-ogsc] .tf-muted,[data-ogsc] .tf-fine{color:#a5b5ac!important}
[data-ogsc] .tf-accent,[data-ogsc] .tf-link{color:#8bd5bb!important}
[data-ogsc] .tf-button-link{color:#133b2e!important}
[data-ogsb] .tf-page{background-color:#111a17!important}
[data-ogsb] .tf-card{background-color:#1a2521!important}
[data-ogsb] .tf-button{background-color:#8bd5bb!important}
[data-ogsb] .tf-code{background-color:#111a17!important}
@media (max-width:480px){.tf-card{padding:26px 20px!important}.tf-headline{font-size:22px!important}}
"""


def _fill(template, **html):
    """The template with its literal text escaped and each placeholder replaced by ready HTML."""
    parts = []
    for literal, field, _, _ in string.Formatter().parse(template):
        parts.append(escape(literal))
        if field is not None:
            parts.append(html[field])
    return "".join(parts)


def _strong(value):
    return f"<strong>{escape(value)}</strong>"


def invitation_html(body):
    """The designed HTML for an invitation's text, or None for any other email."""
    for language, kind, new_user, staging, pattern in _patterns():
        match = pattern.match(body)
        if match:
            break
    else:
        return None
    copy, values = COPY[language], match.groupdict()
    link = values["link"]
    if link.startswith("https://"):
        button = (f'<a class="tf-button-link" href="{escape(link)}" style="display:block;padding:15px 20px;{FONT}'
                  f'font-size:16px;font-weight:600;line-height:1.3;color:{CARD};text-decoration:none;'
                  f'border-radius:14px;">{escape(copy["button"])}</a>')
    else:
        # Only HTTPS links become buttons. A local development address stays readable text.
        button = (f'<p class="tf-button-link" style="margin:0;padding:15px 20px;{FONT}font-size:14px;'
                  f'color:{CARD};word-break:break-all;">{escape(copy["button"])}: {escape(link)}</p>')
    paragraph = f"margin:24px 0 0;{FONT}font-size:15px;line-height:1.6;"
    blocks = []
    if new_user:
        website = (f'<a class="tf-link" href="{WEBSITE}" style="color:{ACCENT};text-decoration:underline;">'
                   f'{escape(WEBSITE.removeprefix("https://").rstrip("/"))}</a>')
        blocks.append(f'<p class="tf-ink" style="{paragraph}color:{INK};">'
                      f'<strong>{escape(copy["new_question"])}</strong> {_fill(copy["new"], website=website)}</p>')
        if staging:
            blocks.append(f'<p class="tf-muted" style="margin:8px 0 0;{FONT}font-size:14px;line-height:1.6;'
                          f'color:{MUTED};">{escape(copy["tester"])}</p>')
    instructions = copy["code_new" if new_user else "code_member"]
    blocks.append(f'<p class="tf-muted" style="{paragraph}color:{MUTED};">'
                  f'{_fill(instructions, email=_strong(values["email"]))}</p>')
    blocks.append('<p class="tf-code" style="margin:8px 0 0;padding:12px 14px;'
                  "font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,'Liberation Mono',monospace;"
                  f'font-size:16px;line-height:1.5;letter-spacing:0.5px;word-break:break-all;color:{INK};'
                  f'background-color:{PAGE};border:1px dashed #c9d6cb;border-radius:12px;">'
                  f'{escape(values["code"])}</p>')
    footer = "".join(f'<p style="margin:0 0 8px;">{"<br>".join(escape(line) for line in part.splitlines())}</p>'
                     for part in (values.get("footer") or "").split("\n\n") if part.strip())
    headline_text = copy["headline"][kind].format(sender=values["sender"], name=values["name"])
    headline = _fill(copy["headline"][kind], sender=_strong(values["sender"]), name=_strong(values["name"]))
    return (
        f'<!DOCTYPE html><html lang="{language}"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">'
        f'<title>{escape(copy["subject"][kind])}</title><style>{STYLE}</style></head>'
        f'<body class="tf-page" style="margin:0;padding:0;background-color:{PAGE};">'
        # The inbox preview: the headline, then blank space instead of the email's first words again.
        '<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;color:transparent;mso-hide:all;">'
        f'{escape(headline_text)}{"&#847;&zwnj;&nbsp;" * 40}</div>'
        '<table role="presentation" class="tf-page" width="100%" cellpadding="0" cellspacing="0" border="0" '
        f'style="background-color:{PAGE};"><tr><td align="center" style="padding:32px 12px;">'
        # Outlook for Windows ignores max-width, so it gets a fixed-width table instead.
        '<!--[if mso]><table role="presentation" width="560" align="center" cellpadding="0" cellspacing="0" '
        'border="0"><tr><td><![endif]-->'
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">'
        f'<tr><td class="tf-ink" style="padding:0 8px 18px;{FONT}font-size:20px;font-weight:700;'
        f'letter-spacing:-0.5px;color:{INK};">&#8599; TaskFlow</td></tr>'
        f'<tr><td class="tf-card" style="background-color:{CARD};border:1px solid {LINE};border-radius:24px;'
        'padding:32px 28px;">'
        f'<p class="tf-accent" style="margin:0 0 12px;{FONT}font-size:12px;font-weight:700;letter-spacing:2px;'
        f'text-transform:uppercase;color:{ACCENT};">{escape(copy["eyebrow"])}</p>'
        f'<h1 class="tf-ink tf-headline" style="margin:0 0 10px;{FONT}font-size:24px;line-height:1.3;font-weight:600;'
        f'letter-spacing:-0.4px;color:{INK};">{headline}</h1>'
        f'<p class="tf-muted" style="margin:0 0 24px;{FONT}font-size:16px;line-height:1.6;color:{MUTED};">'
        f'{escape(copy["what"][kind])}</p>'
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
        f'<td class="tf-button" align="center" bgcolor="{ACCENT}" style="border-radius:14px;background-color:{ACCENT};">'
        f'{button}</td></tr></table>'
        + "".join(blocks) +
        f'<p class="tf-fine" style="margin:24px 0 0;padding-top:18px;border-top:1px solid {LINE};{FONT}'
        f'font-size:13px;line-height:1.6;color:{MUTED};">{escape(copy["fine_print"])}</p>'
        '</td></tr>'
        + (f'<tr><td class="tf-muted" style="padding:20px 8px 0;{FONT}font-size:12px;line-height:1.6;'
           f'color:{MUTED};">{footer}</td></tr>' if footer else "") +
        '</table><!--[if mso]></td></tr></table><![endif]--></td></tr></table></body></html>'
    )
