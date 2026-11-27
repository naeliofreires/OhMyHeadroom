"""Localized terminal presentation for the cleanup CLI."""

from collections.abc import Callable

from ohmyheadroom_engine.features.cleanup.cleanup_types import (
    Category,
    Report,
    ReviewLine,
)
from ohmyheadroom_engine.features.cleanup.scanning.report import (
    disk_free_bytes,
    display_path,
)
from ohmyheadroom_engine.i18n import PORTUGUESE, Localized

MEASURING_NOTICE = Localized(
    pt="Medindo o disco (1 a 3 minutos na primeira vez)...",
    en="Measuring the disk (1 to 3 minutes the first time)...",
)
USAGE = Localized(
    pt=(
        "Uso: python3 cleanup.py [comando] [opções]\n"
        "Comandos: scan (padrão), clean, apply (lê um plano da entrada padrão).\n"
        "  scan --json [--progress]  Gera um relatório JSON e, opcionalmente, eventos de progresso.\n"
        "  scan --scan-root PASTA  Repita para substituir as pastas padrão desta varredura.\n"
        "  clean --yes              Limpa sem pedir confirmação.\n"
        "  --permanent              Apaga de vez, sem mandar para a Lixeira.\n"
        "  apply --json             Executa o plano e retorna a comparação da seleção em JSON.\n"
        "  --lang pt ou --lang en   Escolhe o idioma.\n"
        "  -h, --help               Mostra esta ajuda."
    ),
    en=(
        "Usage: python3 cleanup.py [command] [options]\n"
        "Commands: scan (default), clean, apply (reads a plan from standard input).\n"
        "  scan --json [--progress]  Print a JSON report and optional progress events.\n"
        "  scan --scan-root FOLDER Repeat to replace the default scan roots for this run.\n"
        "  clean --yes              Clean without prompting for confirmation.\n"
        "  --permanent              Delete for good instead of moving to the Trash.\n"
        "  apply --json             Apply the plan and return the selected cleanup comparison as JSON.\n"
        "  --lang pt or --lang en   Choose the language.\n"
        "  -h, --help               Show this help."
    ),
)
MISSING_SCAN_ROOT = Localized(
    pt="Informe uma pasta após --scan-root.",
    en="Specify a folder after --scan-root.",
)
INVALID_SCAN_ROOT = Localized(
    pt="A pasta de busca não está acessível: {path}",
    en="The scan root is not an accessible directory: {path}",
)
INVALID_SCAN_ROOTS_INPUT = Localized(
    pt="Esperava uma lista JSON com caminhos absolutos para as pastas de busca.",
    en="Expected a JSON array of absolute scan root paths.",
)
SCAN_ROOTS_REQUIRE_SCAN = Localized(
    pt="As opções de pastas de busca só estão disponíveis com scan.",
    en="Scan root options are only available with scan.",
)
CONFLICTING_SCAN_ROOTS = Localized(
    pt="Use apenas uma forma de informar as pastas de busca.",
    en="Use only one way to supply scan roots.",
)
REFUSED_PLAN = Localized(
    pt="Plano recusado, nenhuma limpeza foi realizada: {error}",
    en="Plan refused, no cleanup performed: {error}",
)
CONFIRM_QUESTION = Localized(
    pt="\nLimpar '{label}' ({size})? [s/N] ",
    en="\nClear '{label}' ({size})? [y/N] ",
)
SAFE_HEADING = Localized(
    pt="=== SEGURO PARA LIMPAR (o app ou a ferramenta recria os arquivos) ===",
    en="=== SAFE TO CLEAR (the app or tool recreates the files) ===",
)
REVIEW_HEADING = Localized(
    pt="=== REVISÃO MANUAL (o script mantém estes itens no lugar) ===",
    en="=== MANUAL REVIEW (the script leaves these items in place) ===",
)
TOTAL_SAFE = Localized(pt="Total seguro: {size}", en="Total safe: {size}")
FREE_NOW = Localized(pt="Espaço livre agora: {size}", en="Free space now: {size}")
BIGGEST_ITEMS = Localized(pt="caminhos principais:", en="top paths:")
COMMANDS_LABEL = Localized(pt="comandos:", en="commands:")
FREED_THIS_RUN = Localized(
    pt="Liberado nesta rodada: {freed}. Espaço livre agora: {free}",
    en="Freed in this run: {freed}. Free space now: {free}",
)
CANCELLED = Localized(
    pt="Cancelado. A limpeza foi interrompida.", en="Cancelled. Cleanup stopped."
)
NO_ACCESS = Localized(pt="sem acesso", en="no access")

CATEGORY_KIND_LABELS: dict[str, tuple[Localized, Localized]] = {
    "app-caches": (
        Localized(pt="Cache de apps", en="App cache"),
        Localized(pt="Recriado automaticamente", en="Auto-recreated"),
    ),
    "package-caches": (
        Localized(pt="Cache de pacotes", en="Package cache"),
        Localized(pt="Baixado de novo no install", en="Re-downloaded on install"),
    ),
    "editor-caches": (
        Localized(pt="Cache de editores", en="Editor cache"),
        Localized(pt="Recriado automaticamente", en="Auto-recreated"),
    ),
    "logs": (
        Localized(pt="Logs", en="Logs"),
        Localized(pt="Registros descartáveis", en="Disposable records"),
    ),
    "docker-prune": (
        Localized(pt="Docker", en="Docker"),
        Localized(pt="Imagens e cache (sem volumes)", en="Images & cache (volumes kept)"),
    ),
    "deps-worktrees": (
        Localized(pt="Deps de worktrees", en="Worktree deps"),
        Localized(pt="Requer reinstalação", en="Reinstall required"),
    ),
    "deps-projects": (
        Localized(pt="Deps de projetos", en="Project deps"),
        Localized(pt="Requer reinstalação", en="Reinstall required"),
    ),
}
DEFAULT_KIND_LABEL = (
    Localized(pt="Temporário", en="Temporary"),
    Localized(pt="Recriado quando necessário", en="Recreated as needed"),
)


def category_kind_text(key: str, language: str) -> str:
    """Return a concise localized kind + recovery label for a category key."""
    badge, recovery = CATEGORY_KIND_LABELS.get(key, DEFAULT_KIND_LABEL)
    return f"[{badge.for_language(language)} · {recovery.for_language(language)}]"


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
    """Render the localized report. Example: ``print_report(report, 'en')``."""
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
    """Render one category with title, data type, description, and paths or commands."""
    label = category.label.for_language(language)
    kind = category_kind_text(category.key, language)
    print(f"\n {number}. {label} — {format_size(category.size_bytes, language)}")
    print(f"      {kind}")
    print(f"      {category.note.for_language(language)}")
    biggest = category.paths[:3]
    if biggest:
        print(f"      {BIGGEST_ITEMS.for_language(language)}")
        for item in biggest:
            print(f"        - {display_path(item.path)} ({format_size(item.size_bytes, language)})")
    elif category.commands:
        print(f"      {COMMANDS_LABEL.for_language(language)}")
        for command in category.commands:
            print(f"        $ {' '.join(command)}")


def print_review_line(line: ReviewLine, language: str) -> None:
    """Render one review folder, its note, and optional path."""
    print(
        f" - {line.label.for_language(language)} — {format_size(line.size_bytes, language)}"
    )
    print(f"      {line.note.for_language(language)}")
    if line.folder is not None:
        print(f"      {display_path(line.folder)}")


def print_freed_space(free_before: int, free_after: int, language: str) -> None:
    """Render free-space change after cleanup. Example: ``print_freed_space(10, 20, 'en')``."""
    message = FREED_THIS_RUN.render(
        language,
        freed=format_size(free_after - free_before, language),
        free=format_size(free_after, language),
    )
    print(f"\n{message}")
