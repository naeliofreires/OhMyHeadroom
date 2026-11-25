"""Compose the cleanup scan from rule, dependency, and Docker measurements."""

from collections.abc import Callable, Sequence
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import TypeVar

from police_scan_engine.features.cleanup.catalog import (
    DEPENDENCY_DIR_NAMES,
    DEPENDENCY_SCAN_ROOTS,
    HOME,
    REVIEW_RULES,
    SAFE_RULES,
    ReviewRule,
    SafeRule,
)
from police_scan_engine.features.cleanup.cleanup_types import (
    Category,
    Report,
    ReviewLine,
)
from police_scan_engine.features.cleanup.scanning.dependencies import (
    DEPENDENCY_SCAN_LABEL,
    build_dependency_categories,
)
from police_scan_engine.features.cleanup.scanning.docker import (
    DOCKER_PROBE_LABEL,
    build_docker_category,
    build_docker_volume_line,
    docker_reclaimable_bytes,
)
from police_scan_engine.features.cleanup.scanning.measurements import (
    children_of,
    make_category,
    measure_bytes,
    sized_paths,
)
from police_scan_engine.features.cleanup.scanning.progress import ProgressReporter
from police_scan_engine.i18n import Localized
from police_scan_engine.platform.filesystem import FileSystem
from police_scan_engine.platform.processes import ProcessRunner

T = TypeVar("T")
# du spends its time waiting on the disk, not the CPU, so a few running at once finish sooner.
MEASURE_WORKERS = 4
# Jobs besides the rules and review folders: the Docker probe and the dependency walk.
EXTRA_SLOTS = 2


@dataclass(frozen=True)
class ScanRuntime:
    """Runtime inputs for a scan, replaceable by named fakes in tests."""

    filesystem: FileSystem | None = None
    process_runner: ProcessRunner | None = None
    safe_rules: Sequence[SafeRule] = SAFE_RULES
    review_rules: Sequence[ReviewRule] = REVIEW_RULES
    dependency_roots: Sequence[Path] = DEPENDENCY_SCAN_ROOTS
    dependency_dir_names: Sequence[str] = DEPENDENCY_DIR_NAMES


def build_report(
    progress: ProgressReporter | None = None,
    runtime: ScanRuntime | None = None,
) -> Report:
    """Measure the whole Mac once and return the report printed by commands.

    Example: ``report = build_report(); total = sum(c.size_bytes for c in report.safe)``.
    """
    active = runtime or ScanRuntime()
    reporter = progress or ProgressReporter(None)
    reporter.start(len(active.safe_rules) + len(active.review_rules) + EXTRA_SLOTS)
    reporter.step(DOCKER_PROBE_LABEL, "docker system df")
    docker_bytes = docker_reclaimable_bytes(active.process_runner)
    rule_categories, review_lines, dependency_categories = measure_all(reporter, active)
    safe, review = add_docker_results(rule_categories, review_lines, docker_bytes)
    safe.extend(dependency_categories)
    return Report(tuple(safe), tuple(review), disk_free_bytes(active.filesystem))


def add_docker_results(
    categories: list[Category],
    review: list[ReviewLine],
    reclaimable: dict[str, int] | None,
) -> tuple[list[Category], list[ReviewLine]]:
    """Append Docker results in report order. Example: ``add_docker_results([], [], None)``."""
    safe = [*categories]
    lines = [*review]
    if reclaimable is not None:
        safe.append(build_docker_category(reclaimable))
        lines.append(build_docker_volume_line(reclaimable))
    return safe, lines


def measure_all(
    reporter: ProgressReporter,
    runtime: ScanRuntime,
) -> tuple[list[Category], list[ReviewLine], list[Category]]:
    """Measure rules and folders in parallel. Example: ``measure_all(reporter, runtime)``."""
    with ThreadPoolExecutor(max_workers=MEASURE_WORKERS) as pool:
        jobs = submit_all_jobs(pool, reporter, runtime)
        return collect_measurements(*jobs)


def submit_all_jobs(
    pool: ThreadPoolExecutor, reporter: ProgressReporter, runtime: ScanRuntime
) -> tuple[list[Future[Category]], list[Future[ReviewLine]], Future[list[Category]]]:
    """Submit scan jobs to one pool. Example: ``submit_all_jobs(pool, reporter, runtime)``."""
    rules = submit_rule_jobs(
        pool, reporter, runtime.safe_rules, runtime.filesystem, runtime.process_runner
    )
    dependencies = submit_dependency_job(pool, reporter, runtime)
    reviews = submit_review_jobs(
        pool, reporter, runtime.review_rules, runtime.filesystem, runtime.process_runner
    )
    return rules, reviews, dependencies


def collect_measurements(
    rule_jobs: Sequence[Future[Category]],
    review_jobs: Sequence[Future[ReviewLine]],
    dependency_job: Future[list[Category]],
) -> tuple[list[Category], list[ReviewLine], list[Category]]:
    """Collect results in stable order. Example: ``collect_measurements(rules, reviews, deps)``."""
    rules = [job.result() for job in rule_jobs]
    reviews = [job.result() for job in review_jobs]
    dependencies = dependency_job.result()
    return rules, reviews, dependencies


def submit_rule_jobs(
    pool: ThreadPoolExecutor,
    reporter: ProgressReporter,
    rules: Sequence[SafeRule],
    filesystem: FileSystem | None,
    process_runner: ProcessRunner | None,
) -> list[Future[Category]]:
    """Submit safe-rule measurements. Example: ``submit_rule_jobs(pool, reporter, rules, fs, runner)``."""
    return [
        submit_rule_job(pool, reporter, rule, filesystem, process_runner)
        for rule in rules
    ]


def submit_rule_job(
    pool: ThreadPoolExecutor,
    reporter: ProgressReporter,
    rule: SafeRule,
    filesystem: FileSystem | None,
    process_runner: ProcessRunner | None,
) -> Future[Category]:
    """Submit one safe-rule measurement. Example: ``submit_rule_job(pool, reporter, rule, fs, runner)``."""
    return pool.submit(
        measured,
        reporter,
        rule.label,
        rule_path(rule, filesystem),
        build_rule_category,
        rule,
        filesystem,
        process_runner,
    )


def submit_dependency_job(
    pool: ThreadPoolExecutor, reporter: ProgressReporter, runtime: ScanRuntime
) -> Future[list[Category]]:
    """Submit dependency discovery. Example: ``submit_dependency_job(pool, reporter, runtime)``."""
    return pool.submit(
        measured,
        reporter,
        DEPENDENCY_SCAN_LABEL,
        dependency_roots_text(runtime.dependency_roots, runtime.filesystem),
        build_dependency_categories,
        runtime.dependency_roots,
        runtime.dependency_dir_names,
        runtime.filesystem,
        runtime.process_runner,
    )


def submit_review_jobs(
    pool: ThreadPoolExecutor,
    reporter: ProgressReporter,
    rules: Sequence[ReviewRule],
    filesystem: FileSystem | None,
    process_runner: ProcessRunner | None,
) -> list[Future[ReviewLine]]:
    """Submit review-only measurements. Example: ``submit_review_jobs(pool, reporter, rules, fs, runner)``."""
    return [
        submit_review_job(pool, reporter, rule, filesystem, process_runner)
        for rule in rules
    ]


def submit_review_job(
    pool: ThreadPoolExecutor,
    reporter: ProgressReporter,
    rule: ReviewRule,
    filesystem: FileSystem | None,
    process_runner: ProcessRunner | None,
) -> Future[ReviewLine]:
    """Submit one review-only measurement. Example: ``submit_review_job(pool, reporter, rule, fs, runner)``."""
    return pool.submit(
        measured,
        reporter,
        rule.label,
        display_path(rule.folder, filesystem),
        build_review_line,
        rule,
        filesystem,
        process_runner,
    )


def disk_free_bytes(filesystem: FileSystem | None = None) -> int:
    """Return free bytes for the configured home volume. Example: ``disk_free_bytes(fake_fs)``."""
    return (filesystem or FileSystem(HOME)).free_bytes()


def measured(
    reporter: ProgressReporter,
    label: Localized,
    path: str,
    build: Callable[..., T],
    *args: object,
) -> T:
    """Report a job start before measuring. Example: ``measured(reporter, label, path, build)``."""
    reporter.step(label, path)
    return build(*args)


def rule_path(rule: SafeRule, filesystem: FileSystem | None = None) -> str:
    """Render safe-rule folders as ``~/...`` progress paths."""
    return " · ".join(display_path(folder, filesystem) for folder in rule.folders)


def dependency_roots_text(
    roots: Sequence[Path], filesystem: FileSystem | None = None
) -> str:
    """Render dependency roots as ``~/...`` progress paths."""
    return " · ".join(display_path(root, filesystem) for root in roots)


def display_path(path: Path, filesystem: FileSystem | None = None) -> str:
    """Show a path relative to home. Example: ``display_path(path, fake_fs)``."""
    try:
        home = filesystem.home if filesystem is not None else HOME
        return "~/" + str(path.relative_to(home))
    except ValueError:
        return str(path)


def build_rule_category(
    rule: SafeRule,
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
) -> Category:
    """Turn a safe rule into a category. Example: ``build_rule_category(rule, fs, runner)``."""
    children = [
        child for folder in rule.folders for child in children_of(folder, filesystem)
    ]
    return make_category(
        rule.key,
        rule.label,
        rule.note,
        sized_paths(children, filesystem, process_runner),
    )


def build_review_line(
    rule: ReviewRule,
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
) -> ReviewLine:
    """Measure a review folder without deletion. Example: ``build_review_line(rule, fs, runner)``."""
    size_bytes = measure_bytes([rule.folder], filesystem, process_runner)[rule.folder]
    return ReviewLine(rule.label, rule.note, size_bytes, rule.folder)
