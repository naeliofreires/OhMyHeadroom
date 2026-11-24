"""Find regenerable junk on this Mac, and delete it only after you say yes.

Commands (add --lang pt or --lang en; without it the shell's locale decides):
    python3 cleanup.py            same as scan
    python3 cleanup.py scan       show sizes; deletes nothing
    python3 cleanup.py scan --json    the same report as JSON, for the menu bar app
    python3 cleanup.py clean      ask s/N (or y/N) for each safe category, then delete
    python3 cleanup.py clean --yes    delete every safe category without asking
    python3 cleanup.py apply      read a JSON list of categories on stdin and delete them
"""

import os
import shutil
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path

from i18n import PORTUGUESE, Localized, resolve_language
from plan import categories_from_json, report_to_json
from progress import ProgressReporter
from scan import Category, Report, ReviewLine, build_report, disk_free_bytes, display_path
from targets import HOME

SCAN_COMMAND = "scan"
CLEAN_COMMAND = "clean"
APPLY_COMMAND = "apply"
YES_FLAG = "--yes"
JSON_FLAG = "--json"
PROGRESS_FLAG = "--progress"
# Both languages' answers are accepted, so a Portuguese or English prompt both work.
YES_ANSWERS: tuple[str, ...] = ("s", "sim", "y", "yes")
MEASURING_NOTICE = Localized(
    pt="Medindo o disco (1 a 3 minutos na primeira vez)...",
    en="Measuring the disk (1 to 3 minutes the first time)...",
)
USAGE = Localized(
    pt="Comandos: scan | scan --json | clean | clean --yes | apply. "
    "Use --lang pt ou --lang en.",
    en="Commands: scan | scan --json | clean | clean --yes | apply. "
    "Use --lang pt or --lang en.",
)
REFUSED_PLAN = Localized(
    pt="Plano recusado, nada foi apagado: {error}",
    en="Plan refused, nothing was deleted: {error}",
)
CONFIRM_QUESTION = Localized(
    pt="\nApagar '{label}' ({size})? [s/N] ",
    en="\nDelete '{label}' ({size})? [y/N] ",
)
CLEANING = Localized(pt="Limpando: {label}", en="Cleaning: {label}")
COMMAND_OK = Localized(pt="  ok: {command}", en="  ok: {command}")
COMMAND_SKIPPED = Localized(
    pt="  pulei '{command}': {error}",
    en="  skipped '{command}': {error}",
)
COMMAND_FAILED = Localized(
    pt="  falhou ({code}): {command} - {stderr}",
    en="  failed ({code}): {command} - {stderr}",
)
PATH_OUTSIDE_HOME = Localized(
    pt="  pulei {path}: fora da pasta do usuário",
    en="  skipped {path}: outside the user folder",
)
PATH_NOT_DELETED = Localized(
    pt="  não consegui apagar {path}: {error}",
    en="  could not delete {path}: {error}",
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
    pt="Cancelado. Nada mais foi apagado.",
    en="Cancelled. Nothing else was deleted.",
)
NO_ACCESS = Localized(pt="sem acesso", en="no access")


def main(argv: Sequence[str], language: str) -> int:
    """Dispatch to a command; unknown commands print the usage and exit 2."""
    words = positional_words(argv)
    command = words[0] if words else SCAN_COMMAND
    if command == SCAN_COMMAND:
        return run_scan_json(argv) if JSON_FLAG in argv else run_scan(language)
    if command == CLEAN_COMMAND:
        return run_clean(YES_FLAG in argv, language)
    if command == APPLY_COMMAND:
        return run_apply(sys.stdin.read(), language)
    print(USAGE.for_language(language))
    return 2


def positional_words(argv: Sequence[str]) -> list[str]:
    """Words that name a command: flags and the value of --lang are not commands."""
    words = list(argv)
    if "--lang" in words:
        index = words.index("--lang")
        del words[index:index + 2]
    return [word for word in words if not word.startswith("--")]


def run_scan(language: str) -> int:
    """Measure and print the report. Read-only."""
    print(MEASURING_NOTICE.for_language(language), flush=True)
    print_report(build_report(), language)
    return 0


def run_scan_json(argv: Sequence[str]) -> int:
    """Print the report as JSON. Nothing else goes to stdout, so the app can parse it.

    With --progress, each folder being measured is announced on stderr for the app's animation.
    """
    stream = sys.stderr if PROGRESS_FLAG in argv else None
    print(report_to_json(build_report(ProgressReporter(stream))))
    return 0


def run_clean(assume_yes: bool, language: str) -> int:
    """Print the report, then clean each safe category the user confirms."""
    print(MEASURING_NOTICE.for_language(language), flush=True)
    report = build_report()
    print_report(report, language)
    free_before = disk_free_bytes()
    for category in report.safe:
        if confirm_clean(category, assume_yes, language):
            clean_category(category, language)
    print_freed_space(free_before, language)
    return 0


def run_apply(plan_text: str, language: str) -> int:
    """Clean the categories the menu bar app picked. The app already asked the user."""
    try:
        categories = categories_from_json(plan_text)
    except ValueError as error:
        print(REFUSED_PLAN.render(language, error=str(error)), file=sys.stderr)
        return 1
    free_before = disk_free_bytes()
    for category in categories:
        clean_category(category, language)
    print_freed_space(free_before, language)
    return 0


def confirm_clean(category: Category, assume_yes: bool, language: str) -> bool:
    """Ask before each category; --yes skips the question."""
    if assume_yes:
        return True
    question = CONFIRM_QUESTION.render(
        language,
        label=category.label.for_language(language),
        size=format_size(category.size_bytes, language),
    )
    return read_yes(question)


def read_yes(question: str) -> bool:
    """Read one answer. No terminal (EOF) counts as no, so nothing is deleted by accident."""
    try:
        answer = input(question)
    except EOFError:
        return False
    return answer.strip().lower() in YES_ANSWERS


def clean_category(category: Category, language: str) -> None:
    """Run the category's commands (e.g. docker prune), then remove its paths."""
    print(f"\n{CLEANING.render(language, label=category.label.for_language(language))}")
    for command in category.commands:
        run_command(command, language)
    for sized in category.paths:
        remove_path(sized.path, language)


def run_command(command: tuple[str, ...], language: str) -> None:
    """Run one external cleanup command and report its outcome; a failure does not stop the run."""
    command_text = " ".join(command)
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        print(COMMAND_SKIPPED.render(language, command=command_text, error=str(error)))
        return
    if completed.returncode == 0:
        print(COMMAND_OK.render(language, command=command_text))
        return
    print(
        COMMAND_FAILED.render(
            language,
            code=str(completed.returncode),
            command=command_text,
            stderr=completed.stderr.strip(),
        )
    )


def remove_path(path: Path, language: str) -> None:
    """Delete one file, symlink or folder tree.

    Errors are printed rather than raised, so one locked file does not stop the whole run.
    """
    if not is_inside_home(path):
        print(PATH_OUTSIDE_HOME.render(language, path=str(path)))
        return
    try:
        delete_entry(path)
    except OSError as error:
        print(PATH_NOT_DELETED.render(language, path=str(path), error=str(error)))


def delete_entry(path: Path) -> None:
    """Remove a folder tree without following symlinks, or unlink a file or link."""
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
        return
    path.unlink(missing_ok=True)


def is_inside_home(path: Path) -> bool:
    """Guard: a wrong entry in targets.py must never delete anything outside the home folder."""
    parent_resolved = path.parent.resolve()
    return parent_resolved.is_relative_to(HOME.resolve()) and path != HOME


def print_report(report: Report, language: str) -> None:
    """Show the safe categories with sizes, then the review-only lines, then free space."""
    print(f"\n{SAFE_HEADING.for_language(language)}")
    for number, category in enumerate(report.safe, start=1):
        print_category(number, category, language)
    total_bytes = sum(category.size_bytes for category in report.safe)
    print(f"\n{TOTAL_SAFE.render(language, size=format_size(total_bytes, language))}")
    print(f"\n{REVIEW_HEADING.for_language(language)}")
    for line in report.review:
        print_review_line(line, language)
    free_text = format_size(disk_free_bytes(), language)
    print(f"\n{FREE_NOW.render(language, size=free_text)}")


def print_category(number: int, category: Category, language: str) -> None:
    """Print one safe category, its note, and its three biggest items."""
    label = category.label.for_language(language)
    size_text = format_size(category.size_bytes, language)
    print(f"\n {number}. {label}: {size_text}")
    print(f"      {category.note.for_language(language)}")
    biggest = [
        f"{display_path(item.path)} {format_size(item.size_bytes, language)}"
        for item in category.paths[:3]
    ]
    if biggest:
        prefix = BIGGEST_ITEMS.for_language(language)
        print(f"      {prefix}{' · '.join(biggest)}")


def print_review_line(line: ReviewLine, language: str) -> None:
    """Print one review-only folder with its size and a note on what it holds."""
    size_text = format_size(line.size_bytes, language)
    print(f" - {line.label.for_language(language)}: {size_text}")
    print(f"      {line.note.for_language(language)}")


def print_freed_space(free_before: int, language: str) -> None:
    """Report the real change in free space, which includes anything Docker or apps freed."""
    free_after = disk_free_bytes()
    message = FREED_THIS_RUN.render(
        language,
        freed=format_size(free_after - free_before, language),
        free=format_size(free_after, language),
    )
    print(f"\n{message}")


def format_size(size_bytes: int | None, language: str) -> str:
    """Format bytes in decimal units, as Finder and System Settings do, e.g. '58.2 GB'.

    Portuguese uses a decimal comma ('58,2 GB'), like the Mac's Portuguese settings.
    """
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
    number = decimal_text(value, language)
    return f"{sign}{number} {unit}"


def decimal_text(value: float, language: str) -> str:
    """One decimal place, with a comma for Portuguese."""
    text = f"{value:.1f}"
    if language == PORTUGUESE:
        return text.replace(".", ",")
    return text


def run_main() -> int:
    """Entry point: Ctrl-C exits cleanly with the shell's interrupt code instead of a traceback."""
    language = resolve_language(sys.argv[1:], os.environ)
    try:
        return main(sys.argv[1:], language)
    except KeyboardInterrupt:
        print(f"\n{CANCELLED.for_language(language)}")
        return 130


if __name__ == "__main__":
    sys.exit(run_main())
