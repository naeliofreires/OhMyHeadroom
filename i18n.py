"""Portuguese and English text for limpar-mac.

Data (category labels and notes) carries both languages, so the menu bar app can pick
its own language without asking the engine again. Terminal output picks one language,
from --lang or from the shell's locale variables.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

PORTUGUESE = "pt"
ENGLISH = "en"
LANGUAGE_FLAG = "--lang"
# Checked in this order: the first one set decides the terminal language.
LOCALE_VARIABLES: tuple[str, ...] = ("LC_ALL", "LC_MESSAGES", "LANG", "LANGUAGE")


@dataclass(frozen=True)
class Localized:
    """One piece of text in both languages. render() fills in {placeholders}.

    Example: Localized(pt="Total seguro: {size}", en="Total safe: {size}").render("en", size="2 GB")
    """

    pt: str
    en: str

    def for_language(self, language: str) -> str:
        """Return the text for one language. Any language other than Portuguese gets English."""
        if language == PORTUGUESE:
            return self.pt
        return self.en

    def render(self, language: str, **values: str) -> str:
        """Return the chosen language's text with its {placeholders} filled in."""
        return self.for_language(language).format(**values)

    def with_suffix(self, other: "Localized") -> "Localized":
        """Join two sentences in both languages, separated by a space."""
        return Localized(pt=f"{self.pt} {other.pt}", en=f"{self.en} {other.en}")


def normalize_language(code: str) -> str:
    """Map a locale code such as 'pt_BR.UTF-8', 'pt-BR' or 'en_US' to 'pt' or 'en'."""
    if code.lower().startswith("pt"):
        return PORTUGUESE
    return ENGLISH


def language_from_environment(environment: Mapping[str, str]) -> str:
    """Use the first locale variable that is set; with none set, English is the fallback."""
    for name in LOCALE_VARIABLES:
        value = environment.get(name, "")
        if value:
            return normalize_language(value)
    return ENGLISH


def resolve_language(argv: Sequence[str], environment: Mapping[str, str]) -> str:
    """--lang wins over the shell locale, so the menu bar app can ask for a language."""
    words = list(argv)
    if LANGUAGE_FLAG in words:
        index = words.index(LANGUAGE_FLAG)
        if index + 1 < len(words):
            return normalize_language(words[index + 1])
    return language_from_environment(environment)
