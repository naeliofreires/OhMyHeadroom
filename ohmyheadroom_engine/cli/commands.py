"""CLI orchestration for the cleanup feature."""

import os
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Callable, TextIO

from ohmyheadroom_engine.cli.presentation import (
    CANCELLED,
    CONFIRM_QUESTION,
    MEASURING_NOTICE,
    REFUSED_PLAN,
    USAGE,
    format_size,
    print_freed_space,
    print_report,
)
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, Report
from ohmyheadroom_engine.features.cleanup.contracts import (
    categories_from_json,
    report_to_json,
)
from ohmyheadroom_engine.features.cleanup.execution.runner import clean_category
from ohmyheadroom_engine.features.cleanup.scanning.report import (
    build_report,
    disk_free_bytes,
)
from ohmyheadroom_engine.features.cleanup.scanning.progress import ProgressReporter
from ohmyheadroom_engine.i18n import resolve_language

SCAN_COMMAND = "scan"
CLEAN_COMMAND = "clean"
APPLY_COMMAND = "apply"
YES_FLAG = "--yes"
JSON_FLAG = "--json"
PROGRESS_FLAG = "--progress"
# Portuguese and English affirmative answers are accepted by the same CLI.
YES_ANSWERS: tuple[str, ...] = ("s", "sim", "y", "yes")


@dataclass(frozen=True)
class CleanupOperations:
    """Injected runtime operations. Example: ``ops = default_operations()``."""

    scan: Callable[[], Report]
    scan_with_progress: Callable[[TextIO | None], Report]
    free_bytes: Callable[[], int]
    apply: Callable[[Category, str], None]


def default_operations() -> CleanupOperations:
    """Build production operations. Example: ``ops = default_operations()``."""
    return CleanupOperations(
        scan=build_report,
        scan_with_progress=lambda stream: build_report(ProgressReporter(stream)),
        free_bytes=disk_free_bytes,
        apply=clean_category,
    )


def main(
    argv: Sequence[str], language: str, operations: CleanupOperations | None = None
) -> int:
    """Dispatch a command with legacy exit codes. Example: ``main([], 'en')``."""
    active = operations or default_operations()
    words = positional_words(argv)
    command = words[0] if words else SCAN_COMMAND
    if command == SCAN_COMMAND:
        return (
            run_scan_json(argv, active)
            if JSON_FLAG in argv
            else run_scan(language, active)
        )
    if command == CLEAN_COMMAND:
        return run_clean(YES_FLAG in argv, language, active)
    if command == APPLY_COMMAND:
        return run_apply(sys.stdin.read(), language, active)
    print(USAGE.for_language(language))
    return 2


def positional_words(argv: Sequence[str]) -> list[str]:
    """Return command words after options. Example: ``positional_words(['scan', '--json'])``."""
    words = list(argv)
    if "--lang" in words:
        index = words.index("--lang")
        del words[index : index + 2]
    return [word for word in words if not word.startswith("--")]


def run_scan(language: str, operations: CleanupOperations | None = None) -> int:
    """Measure and print a human report. Example: ``run_scan('en', ops)``."""
    print(MEASURING_NOTICE.for_language(language), flush=True)
    active = operations or default_operations()
    report = active.scan()
    print_report(report, language, active.free_bytes)
    return 0


def run_scan_json(
    argv: Sequence[str], operations: CleanupOperations | None = None
) -> int:
    """Print report JSON and optional progress. Example: ``run_scan_json(['--json'], ops)``."""
    stream = sys.stderr if PROGRESS_FLAG in argv else None
    active = operations or default_operations()
    report = active.scan_with_progress(stream)
    print(report_to_json(report))
    return 0


def run_clean(
    assume_yes: bool, language: str, operations: CleanupOperations | None = None
) -> int:
    """Confirm and apply safe categories. Example: ``run_clean(True, 'en', ops)``."""
    print(MEASURING_NOTICE.for_language(language), flush=True)
    active = operations or default_operations()
    report = active.scan()
    print_report(report, language, active.free_bytes)
    free_before = active.free_bytes()
    for category in report.safe:
        if confirm_clean(category, assume_yes, language):
            active.apply(category, language)
    print_freed_space(free_before, active.free_bytes(), language)
    return 0


def run_apply(
    plan_text: str, language: str, operations: CleanupOperations | None = None
) -> int:
    """Parse a complete plan before effects. Example: ``run_apply(plan, 'en', ops)``."""
    try:
        categories = categories_from_json(plan_text)
    except ValueError as error:
        print(REFUSED_PLAN.render(language, error=str(error)), file=sys.stderr)
        return 1
    active = operations or default_operations()
    free_before = active.free_bytes()
    for category in categories:
        active.apply(category, language)
    print_freed_space(free_before, active.free_bytes(), language)
    return 0


def confirm_clean(category: Category, assume_yes: bool, language: str) -> bool:
    """Ask before one category unless yes. Example: ``confirm_clean(category, True, 'en')``."""
    if assume_yes:
        return True
    question = CONFIRM_QUESTION.render(
        language,
        label=category.label.for_language(language),
        size=format_size(category.size_bytes, language),
    )
    return read_yes(question)


def read_yes(question: str) -> bool:
    """Treat EOF as negative. Example: ``read_yes('Clear? ')``."""
    try:
        answer = input(question)
    except EOFError:
        return False
    return answer.strip().lower() in YES_ANSWERS


def run_main() -> int:
    """Resolve locale and dispatch CLI. Example: ``exit(run_main())``."""
    language = resolve_language(sys.argv[1:], os.environ)
    try:
        return main(sys.argv[1:], language)
    except KeyboardInterrupt:
        print(f"\n{CANCELLED.for_language(language)}")
        return 130
