"""Terminal presentation and exact legacy text for the cleanup CLI."""

from collections.abc import Callable

from police_scan_engine.features.cleanup.cleanup_types import (
    Category,
    Report,
    ReviewLine,
)
from police_scan_engine.features.cleanup.scanning.report import (
    disk_free_bytes,
    display_path,
)
from police_scan_engine.i18n import PORTUGUESE, Localized

MEASURING_NOTICE = Localized(
    pt="Medindo o disco (1 a 3 minutos na primeira vez)...",
    en="Measuring the disk (1 to 3 minutes the first time)...",
)
USAGE = Localized(
    pt="Comandos: scan | scan --json | clean | clean --yes | apply. Use --lang pt ou --lang en.",
    en="Commands: scan | scan --json | clean | clean --yes | apply. Use --lang pt or --lang en.",
)
REFUSED_PLAN = Localized(
    pt="Plano recusado, nada foi apagado: {error}",
    en="Plan refused, nothing was deleted: {error}",
)
CONFIRM_QUESTION = Localized(
    pt="\nApagar '{label}' ({size})? [s/N] ", en="\nDelete '{label}' ({size})? [y/N] "
)
SAFE_HEADING = Localized(
    pt="=== SEGURO PARA APAGAR (o app ou a ferramenta recria) ===",
    en="=== SAFE TO DELETE (the app or tool recreates it) ===",
)
REVIEW_HEADING = Localized(
    pt="=== REVISAR VOCÊ MESMO (o script não apaga isto) ===",
    en="=== REVIEW YOURSELF (the script deletes none of this) ===",
)
TOTAL_SAFE = Localized(pt="Total seguro: {size}", en="Total safe: {size}")
FREE_NOW = Localized(pt="Espaço livre agora: {size}", en="Free space now: {size}")
BIGGEST_ITEMS = Localized(pt="maiores: ", en="biggest: ")
FREED_THIS_RUN = Localized(
    pt="Liberado nesta rodada: {freed}. Espaço livre agora: {free}",
    en="Freed in this run: {freed}. Free space now: {free}",
)
CANCELLED = Localized(
    pt="Cancelado. Nada mais foi apagado.", en="Cancelled. Nothing else was deleted."
)
NO_ACCESS = Localized(pt="sem acesso", en="no access")


def format_size(size_bytes: int | None, language: str) -> str:
    """Format bytes using decimal units. Example: ``format_size(1234, 'en')``."""
    if size_bytes is None:
        return NO_ACCESS.for_language(language)
    sign = "-" if size_bytes < 0 else ""
    value = float(abs(size_bytes))
    unit = "B"
    for next_unit in ("KB", "MB", "GB", "TB"):
        if value < 1000:
            break
        value /= 1000
        unit = next_unit
    decimal = f"{value:.1f}"
    if language == PORTUGUESE:
        decimal = decimal.replace(".", ",")
    return f"{sign}{decimal} {unit}"


def print_report(
    report: Report, language: str, free_bytes: Callable[[], int] | None = None
) -> None:
    """Render the report with legacy wording. Example: ``print_report(report, 'en')``."""
    print(f"\n{SAFE_HEADING.for_language(language)}")
    for number, category in enumerate(report.safe, start=1):
        print_category(number, category, language)
    total_bytes = sum(category.size_bytes for category in report.safe)
    print(f"\n{TOTAL_SAFE.render(language, size=format_size(total_bytes, language))}")
    print(f"\n{REVIEW_HEADING.for_language(language)}")
    for line in report.review:
        print_review_line(line, language)
    current_free = disk_free_bytes() if free_bytes is None else free_bytes()
    print(f"\n{FREE_NOW.render(language, size=format_size(current_free, language))}")


def print_category(number: int, category: Category, language: str) -> None:
    """Render one category and its largest paths. Example: ``print_category(1, category, 'en')``."""
    label = category.label.for_language(language)
    print(f"\n {number}. {label}: {format_size(category.size_bytes, language)}")
    print(f"      {category.note.for_language(language)}")
    biggest = [
        f"{display_path(item.path)} {format_size(item.size_bytes, language)}"
        for item in category.paths[:3]
    ]
    if biggest:
        print(f"      {BIGGEST_ITEMS.for_language(language)}{' · '.join(biggest)}")


def print_review_line(line: ReviewLine, language: str) -> None:
    """Render one review folder and its note. Example: ``print_review_line(line, 'en')``."""
    print(
        f" - {line.label.for_language(language)}: {format_size(line.size_bytes, language)}"
    )
    print(f"      {line.note.for_language(language)}")


def print_freed_space(free_before: int, free_after: int, language: str) -> None:
    """Render free-space change after cleanup. Example: ``print_freed_space(10, 20, 'en')``."""
    message = FREED_THIS_RUN.render(
        language,
        freed=format_size(free_after - free_before, language),
        free=format_size(free_after, language),
    )
    print(f"\n{message}")
