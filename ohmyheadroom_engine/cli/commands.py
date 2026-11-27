"""CLI orchestration for the cleanup feature."""

import io
import json
import os
import sys
from collections.abc import Sequence
from contextlib import nullcontext, redirect_stdout
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, TextIO

from ohmyheadroom_engine.cli.presentation import (
    CANCELLED,
    CONFIRM_QUESTION,
    CONFLICTING_SCAN_ROOTS,
    INVALID_SCAN_ROOT,
    INVALID_SCAN_ROOTS_INPUT,
    MEASURING_NOTICE,
    MISSING_SCAN_ROOT,
    REFUSED_PLAN,
    SCAN_ROOTS_REQUIRE_SCAN,
    USAGE,
    format_size,
    print_freed_space,
    print_report,
)
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, CleanupResult, Report
from ohmyheadroom_engine.features.cleanup.contracts import (
    categories_from_json,
    cleanup_result_to_json,
    report_to_json,
)
from ohmyheadroom_engine.features.cleanup.execution.runner import DeleteMode, clean_category
from ohmyheadroom_engine.features.cleanup.scanning.measurements import measure_selected_bytes
from ohmyheadroom_engine.features.cleanup.scanning.report import (
    ScanRuntime,
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
PERMANENT_FLAG = "--permanent"
PROGRESS_FLAG = "--progress"
SCAN_ROOT_FLAG = "--scan-root"
SCAN_ROOTS_STDIN_FLAG = "--scan-roots-stdin"
HELP_FLAGS = ("-h", "--help")
# Portuguese and English affirmative answers are accepted by the same CLI.
YES_ANSWERS: tuple[str, ...] = ("s", "sim", "y", "yes")


@dataclass(frozen=True)
class CleanupOperations:
    """Injected runtime operations. Example: ``ops = default_operations()``."""

    scan: Callable[[], Report]
    scan_with_progress: Callable[[TextIO | None], Report]
    free_bytes: Callable[[], int]
    apply: Callable[[Category, str, DeleteMode], None]
    measure_selected: Callable[[Sequence[Category]], int | None]


def default_operations(dependency_roots: Sequence[Path] | None = None) -> CleanupOperations:
    """Build production operations for the requested dependency search roots."""
    runtime = None if dependency_roots is None else ScanRuntime(dependency_roots=dependency_roots)
    return CleanupOperations(
        scan=lambda: build_report(runtime=runtime),
        scan_with_progress=lambda stream: build_report(ProgressReporter(stream), runtime),
        free_bytes=disk_free_bytes,
        apply=apply_category,
        measure_selected=measure_selected_bytes,
    )


def main(
    argv: Sequence[str], language: str, operations: CleanupOperations | None = None
) -> int:
    """Dispatch a command with legacy exit codes. Example: ``main([], 'en')``."""
    if any(flag in argv for flag in HELP_FLAGS):
        print(USAGE.for_language(language))
        return 0

    try:
        argv, dependency_roots = scan_options(argv, language)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2
    active = operations or default_operations(dependency_roots)
    words = positional_words(argv)
    command = words[0] if words else SCAN_COMMAND
    if command == SCAN_COMMAND:
        return (
            run_scan_json(argv, active)
            if JSON_FLAG in argv
            else run_scan(language, active)
        )
    delete_mode = delete_mode_from(argv)
    if command == CLEAN_COMMAND:
        return run_clean(YES_FLAG in argv, language, active, delete_mode)
    if command == APPLY_COMMAND:
        return run_apply(
            sys.stdin.read(),
            language,
            active,
            json_output=JSON_FLAG in argv,
            mode=delete_mode,
        )
    print(USAGE.for_language(language))
    return 2


def apply_category(category: Category, language: str, mode: DeleteMode) -> None:
    """Clean one category with the chosen mode. Example: ``apply_category(category, 'en', mode)``."""
    clean_category(category, language, mode=mode)


def delete_mode_from(argv: Sequence[str]) -> DeleteMode:
    """Pick the Trash unless --permanent is given. Example: ``delete_mode_from(['clean'])``."""
    if PERMANENT_FLAG in argv:
        return DeleteMode.PERMANENT
    return DeleteMode.TRASH


def positional_words(argv: Sequence[str]) -> list[str]:
    """Return command words after options. Example: ``positional_words(['scan', '--json'])``."""
    words = list(argv)
    if "--lang" in words:
        index = words.index("--lang")
        del words[index : index + 2]
    return [word for word in words if not word.startswith("--")]


def scan_options(argv: Sequence[str], language: str) -> tuple[list[str], tuple[Path, ...] | None]:
    """Extract scan roots while leaving the other command arguments intact."""
    remaining: list[str] = []
    explicit: list[str] = []
    from_stdin = False
    words = iter(argv)
    for word in words:
        flag, separator, value = word.partition("=")
        if flag == SCAN_ROOT_FLAG:
            if not separator:
                value = next(words, "")
                if value.startswith("-"):
                    value = ""
            if not value:
                raise ValueError(MISSING_SCAN_ROOT.for_language(language))
            explicit.append(value)
        elif word == SCAN_ROOTS_STDIN_FLAG:
            from_stdin = True
        else:
            remaining.append(word)

    if not explicit and not from_stdin:
        return remaining, None
    command_words = positional_words(remaining)
    if command_words and command_words[0] != SCAN_COMMAND:
        raise ValueError(SCAN_ROOTS_REQUIRE_SCAN.for_language(language))
    if from_stdin and explicit:
        raise ValueError(CONFLICTING_SCAN_ROOTS.for_language(language))
    if from_stdin:
        return remaining, scan_roots_from_stdin(language)
    return remaining, tuple(checked_scan_root(value, language) for value in explicit)


def scan_roots_from_stdin(language: str) -> tuple[Path, ...]:
    """Read the app's absolute paths without requiring previously saved folders to exist."""
    message = INVALID_SCAN_ROOTS_INPUT.for_language(language)
    try:
        decoded: object = json.load(sys.stdin)
    except ValueError as error:
        raise ValueError(message) from error
    if not isinstance(decoded, list) or not all(
        isinstance(value, str) and value.startswith("/") and "\0" not in value
        for value in decoded
    ):
        raise ValueError(message)
    return tuple(Path(value) for value in decoded)


def checked_scan_root(value: str, language: str) -> Path:
    """Expand a CLI path and verify it can be walked before running the scan."""
    try:
        root = Path(value).expanduser().resolve(strict=True)
        with os.scandir(root):
            if os.access(root, os.X_OK):
                return root
    except (OSError, RuntimeError, ValueError):
        pass
    raise ValueError(INVALID_SCAN_ROOT.render(language, path=repr(value)))


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
    assume_yes: bool,
    language: str,
    operations: CleanupOperations | None = None,
    mode: DeleteMode = DeleteMode.TRASH,
) -> int:
    """Confirm and apply safe categories. Example: ``run_clean(True, 'en', ops)``."""
    print(MEASURING_NOTICE.for_language(language), flush=True)
    active = operations or default_operations()
    report = active.scan()
    print_report(report, language, active.free_bytes)
    free_before = active.free_bytes()
    for category in report.safe:
        if confirm_clean(category, assume_yes, language):
            active.apply(category, language, mode)
    print_freed_space(free_before, active.free_bytes(), language)
    return 0


def run_apply(
    plan_text: str,
    language: str,
    operations: CleanupOperations | None = None,
    *,
    json_output: bool = False,
    mode: DeleteMode = DeleteMode.TRASH,
) -> int:
    """Parse a complete plan before effects. Example: ``run_apply(plan, 'en', ops)``."""
    try:
        categories = categories_from_json(plan_text)
    except ValueError as error:
        print(REFUSED_PLAN.render(language, error=str(error)), file=sys.stderr)
        return 1
    active = operations or default_operations()
    before_bytes = sum(category.size_bytes for category in categories) if json_output else 0
    log = io.StringIO() if json_output else None
    with redirect_stdout(log) if log is not None else nullcontext():
        free_before = active.free_bytes()
        for category in categories:
            active.apply(category, language, mode)
        print_freed_space(free_before, active.free_bytes(), language)
    if log is not None:
        after_bytes = active.measure_selected(categories)
        print(cleanup_result_to_json(CleanupResult(before_bytes, after_bytes, log.getvalue())))
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
