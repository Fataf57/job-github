"""Normalisation des numéros de téléphone pour l'unicité des comptes."""
import re


def normalize_telephone(value: str) -> str:
    """
    Forme canonique pour éviter plusieurs comptes avec le même numéro
    saisi différemment (+226 70…, 070…, 22670…).
    """
    if not value:
        return ''
    s = value.strip()
    digits = re.sub(r'\D', '', s)
    if not digits:
        return s

    if digits.startswith('00226'):
        digits = digits[5:]
    elif digits.startswith('00'):
        digits = digits[2:]

    # Burkina : 0XXXXXXXX (9 chiffres)
    if len(digits) == 9 and digits.startswith('0'):
        return f'+226{digits[1:]}'

    # 226XXXXXXXX (11 chiffres)
    if digits.startswith('226') and len(digits) == 11:
        return f'+{digits}'

    # XXXXXXXX (8 chiffres, mobile local)
    if len(digits) == 8:
        return f'+226{digits}'

    if s.startswith('+'):
        return f'+{digits}'

    return digits
