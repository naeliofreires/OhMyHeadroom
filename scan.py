"""Measures every rule in targets.py and turns the numbers into a report.

Nothing here deletes anything: limpar.py decides when to act on these numbers.
Labels and notes stay bilingual, so the report reads the same for every client.
"""

import os
import re
import shutil
import subprocess
from collections.abc import Callable, Sequence
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import TypeVar

from i18n import Localized
from progress import ProgressReporter
from targets import (
    DEPENDENCY_DIR_NAMES,
    DEPENDENCY_SCAN_ROOTS,
    HOME,
    REVIEW_RULES,
    SAFE_RULES,
    ReviewRule,
    SafeRule,
)

T = TypeVar("T")
# du spends its time waiting on the disk, not the CPU, so a few running at once finish sooner.
MEASURE_WORKERS = 4
# Jobs besides the rules and review folders: the Docker probe and the dependency walk.
EXTRA_SLOTS = 2
DOCKER_DF_FORMAT = "{{.Type}}|{{.Reclaimable}}"
DOCKER_SIZE_PATTERN = re.compile(r"^([\d.]+)(B|kB|MB|GB|TB)\b")
# Docker reports decimal units (1 GB = 1000 MB), not the binary ones du uses.
DOCKER_UNIT_BYTES: dict[str, int] = {
    "B": 1,
    "kB": 1000,
    "MB": 1000**2,
    "GB": 1000**3,
    "TB": 1000**4,
}
DOCKER_PRUNE_COMMANDS: tuple[tuple[str, ...], ...] = (
    ("docker", "image", "prune", "-a", "-f"),
    ("docker", "builder", "prune", "-f"),
)

DEPENDENCY_NOTE_PROJECTS = Localized(
    pt="Reinstale com npm install / uv sync antes de rodar o projeto de novo.",
    en="Reinstall with npm install / uv sync before running the project again.",
)
DEPENDENCY_NOTE_WORKTREES = Localized(
    pt="Worktrees de agentes e do Herdr. Se um agente estiver rodando nele agora, "
    "reinstale depois.",
    en="Agent and Herdr worktrees. If an agent is running in one right now, "
    "reinstall afterwards.",
)
WORKTREE_DEPENDENCIES_LABEL = Localized(
    pt="Dependências e builds em worktrees (agentes, Herdr)",
    en="Dependencies and builds in worktrees (agents, Herdr)",
)
PROJECT_DEPENDENCIES_LABEL = Localized(
    pt="Dependências e builds em projetos",
    en="Dependencies and builds in projects",
)
DOCKER_PRUNE_LABEL = Localized(
    pt="Docker: imagens e build cache sem uso",
    en="Docker: unused images and build cache",
)
DOCKER_PRUNE_NOTE = Localized(
    pt="Imagens sem container são baixadas ou refeitas depois. Volumes NÃO são tocados.",
    en="Images without a container are downloaded or rebuilt later. Volumes are NOT touched.",
)
DOCKER_VOLUMES_LABEL = Localized(pt="Docker: volumes sem uso", en="Docker: unused volumes")
DOCKER_VOLUMES_NOTE = Localized(
    pt="Podem guardar dados de bancos. Confira com: docker volume ls -f dangling=true",
    en="They may hold database data. Check with: docker volume ls -f dangling=true",
)
DOCKER_PROBE_LABEL = Localized(pt="Docker: imagens e volumes", en="Docker: images and volumes")
DEPENDENCY_SCAN_LABEL = Localized(
    pt="Dependências e builds (node_modules, .venv)",
    en="Dependencies and builds (node_modules, .venv)",
)


@dataclass(frozen=True)
class SizedPath:
    """A path with the bytes it occupies on disk."""

    path: Path
    size_bytes: int


@dataclass(frozen=True)
class Category:
    """One safe-to-clean line of the report, with what cleaning removes and runs."""

    key: str
    label: Localized
    note: Localized
    size_bytes: int
    paths: tuple[SizedPath, ...] = ()
    commands: tuple[tuple[str, ...], ...] = ()


@dataclass(frozen=True)
class ReviewLine:
    """A folder the user decides about. size_bytes is None when macOS blocks reading it.

    folder is None for lines that are not a folder (Docker volumes live inside the VM).
    """

    label: Localized
    note: Localized
    size_bytes: int | None
    folder: Path | None


@dataclass(frozen=True)
class Report:
    """Everything the scan found: safe categories, review-only lines, and free space."""

    safe: tuple[Category, ...]
    review: tuple[ReviewLine, ...]
    free_bytes: int


def build_report(progress: ProgressReporter | None = None) -> Report:
    """Measure the whole Mac once and return the report both commands print.

    progress is told about each folder before it is measured, for the menu bar app.
    Example: report = build_report(); total = sum(c.size_bytes for c in report.safe)
    """
    reporter = progress if progress is not None else ProgressReporter(None)
    reporter.start(len(SAFE_RULES) + len(REVIEW_RULES) + EXTRA_SLOTS)
    reporter.step(DOCKER_PROBE_LABEL, "docker system df")
    docker_bytes = docker_reclaimable_bytes()
    rule_categories, review_lines, dependency_categories = measure_all(reporter)

    # Docker is probed before the parallel jobs, so its lines come after the rules here.
    safe = [*rule_categories]
    if docker_bytes is not None:
        safe.append(build_docker_category(docker_bytes))
        review_lines.append(build_docker_volume_line(docker_bytes))
    safe.extend(dependency_categories)
    return Report(
        safe=tuple(safe),
        review=tuple(review_lines),
        free_bytes=disk_free_bytes(),
    )


def measure_all(reporter: ProgressReporter) -> tuple[list[Category], list[ReviewLine], list[Category]]:
    """Measure every rule, review folder and dependency folder in parallel.

    Returns (rule categories, review lines, dependency categories), in the order they were defined.
    """
    with ThreadPoolExecutor(max_workers=MEASURE_WORKERS) as pool:
        rule_jobs = [
            pool.submit(measured, reporter, rule.label, rule_path(rule), build_rule_category, rule)
            for rule in SAFE_RULES
        ]
        dependency_job = pool.submit(
            measured,
            reporter,
            DEPENDENCY_SCAN_LABEL,
            dependency_roots_text(),
            build_dependency_categories,
        )
        review_jobs = [
            pool.submit(
                measured,
                reporter,
                rule.label,
                display_path(rule.folder),
                build_review_line,
                rule,
            )
            for rule in REVIEW_RULES
        ]
        rule_categories = [job.result() for job in rule_jobs]
        review_lines = [job.result() for job in review_jobs]
        dependency_categories = dependency_job.result()
    return rule_categories, review_lines, dependency_categories


def disk_free_bytes() -> int:
    """Free bytes on the volume that holds the home folder."""
    return shutil.disk_usage(HOME).free


def measured(
    reporter: ProgressReporter,
    label: Localized,
    path: str,
    build: Callable[..., T],
    *args: object,
) -> T:
    """Tell the reporter which folder is starting, then run its measurement."""
    reporter.step(label, path)
    return build(*args)


def rule_path(rule: SafeRule) -> str:
    """The rule's folders as ~/... paths, for the progress caption."""
    return " · ".join(display_path(folder) for folder in rule.folders)


def dependency_roots_text() -> str:
    """The folders the dependency walk starts from, as ~/... paths."""
    return " · ".join(display_path(root) for root in DEPENDENCY_SCAN_ROOTS)


def display_path(path: Path) -> str:
    """Show paths relative to the home folder, as ~/..., so the report stays readable."""
    try:
        return "~/" + str(path.relative_to(HOME))
    except ValueError:
        return str(path)


def build_rule_category(rule: SafeRule) -> Category:
    """Turn one SafeRule into a Category whose removable paths are the folder contents."""
    children: list[Path] = []
    for folder in rule.folders:
        children.extend(children_of(folder))
    return make_category(rule.key, rule.label, rule.note, sized_paths(children))


def build_review_line(rule: ReviewRule) -> ReviewLine:
    """Measure a review-only folder without marking anything for deletion."""
    size_bytes = measure_bytes([rule.folder])[rule.folder]
    return ReviewLine(
        label=rule.label,
        note=rule.note,
        size_bytes=size_bytes,
        folder=rule.folder,
    )


def build_docker_category(reclaimable: dict[str, int]) -> Category:
    """Images and build cache are regenerable; volumes are deliberately left out."""
    size_bytes = reclaimable.get("Images", 0) + reclaimable.get("Build Cache", 0)
    return Category(
        key="docker-prune",
        label=DOCKER_PRUNE_LABEL,
        note=DOCKER_PRUNE_NOTE,
        size_bytes=size_bytes,
        commands=DOCKER_PRUNE_COMMANDS,
    )


def build_docker_volume_line(reclaimable: dict[str, int]) -> ReviewLine:
    """Unused volumes can hold database data, so they are only reported."""
    return ReviewLine(
        label=DOCKER_VOLUMES_LABEL,
        note=DOCKER_VOLUMES_NOTE,
        size_bytes=reclaimable.get("Local Volumes", 0),
        folder=None,
    )


def build_dependency_categories() -> list[Category]:
    """Split node_modules and friends into worktree copies and main-project copies."""
    dependency_dirs: list[Path] = []
    for root in DEPENDENCY_SCAN_ROOTS:
        dependency_dirs.extend(find_dependency_dirs(root))
    sized = sized_paths(dependency_dirs)
    worktree_items = [item for item in sized if is_worktree_path(item.path)]
    project_items = [item for item in sized if not is_worktree_path(item.path)]
    return [
        make_category(
            "deps-worktrees",
            WORKTREE_DEPENDENCIES_LABEL,
            DEPENDENCY_NOTE_WORKTREES,
            worktree_items,
        ),
        make_category(
            "deps-projects",
            PROJECT_DEPENDENCIES_LABEL,
            DEPENDENCY_NOTE_PROJECTS,
            project_items,
        ),
    ]


def find_dependency_dirs(root: Path) -> list[Path]:
    """Walk a root and return dependency folders, without descending into them or .git."""
    if not root.is_dir():
        return []
    found: list[Path] = []
    for current_text, subdir_names, _file_names in os.walk(root):
        found.extend(
            Path(current_text, name) for name in subdir_names if name in DEPENDENCY_DIR_NAMES
        )
        # Pruning in place stops os.walk from entering the folders we just recorded.
        subdir_names[:] = [name for name in subdir_names if is_walkable(name)]
    return found


def is_walkable(name: str) -> bool:
    """Skip dependency folders (already recorded) and git metadata."""
    return name not in DEPENDENCY_DIR_NAMES and name != ".git"


def is_worktree_path(path: Path) -> bool:
    """Worktrees live under a folder literally named 'worktrees' (.claude, .slim, .herdr...)."""
    return "worktrees" in path.parts


def docker_reclaimable_bytes() -> dict[str, int] | None:
    """Map Docker's resource types to reclaimable bytes; None when Docker is not usable."""
    try:
        completed = subprocess.run(
            ["docker", "system", "df", "--format", DOCKER_DF_FORMAT],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    if completed.returncode != 0:
        return None
    return parse_docker_df(completed.stdout)


def parse_docker_df(output: str) -> dict[str, int]:
    """Parse 'Images|2.458GB (7%)' lines into {'Images': 2458000000}."""
    reclaimable: dict[str, int] = {}
    for line in output.splitlines():
        type_name, _, size_text = line.partition("|")
        reclaimable[type_name] = parse_docker_size(size_text)
    return reclaimable


def parse_docker_size(text: str) -> int:
    """Convert Docker's size text such as '2.458GB (7%)' into bytes."""
    match = DOCKER_SIZE_PATTERN.match(text.strip())
    if match is None:
        raise ValueError(
            f"tamanho do Docker não reconhecido: {text!r}; esperado algo como '2.458GB (7%)'"
        )
    return int(float(match.group(1)) * DOCKER_UNIT_BYTES[match.group(2)])


def children_of(folder: Path) -> list[Path]:
    """Everything directly inside a folder; a missing or unreadable folder has none."""
    try:
        return sorted(folder.iterdir())
    except OSError:
        return []


def sized_paths(paths: Sequence[Path]) -> list[SizedPath]:
    """Pair each path with its size, biggest first, treating unreadable paths as 0 bytes."""
    sizes = measure_bytes(paths)
    sized = [SizedPath(path=path, size_bytes=size or 0) for path, size in sizes.items()]
    return sorted(sized, key=lambda item: item.size_bytes, reverse=True)


def make_category(
    key: str,
    label: Localized,
    note: Localized,
    paths: list[SizedPath],
    commands: tuple[tuple[str, ...], ...] = (),
) -> Category:
    """Build a Category whose size is the sum of the paths it would remove."""
    total_bytes = sum(item.size_bytes for item in paths)
    return Category(
        key=key,
        label=label,
        note=note,
        size_bytes=total_bytes,
        paths=tuple(paths),
        commands=commands,
    )


def measure_bytes(paths: Sequence[Path]) -> dict[Path, int | None]:
    """Size in bytes of each path, or None when it exists but macOS refuses to read it.

    One du call covers the whole batch: starting du per path is slow when a folder
    holds thousands of small entries.
    """
    if not paths:
        return {}
    sizes_by_text = run_du(paths)
    return {path: resolve_size(path, sizes_by_text) for path in paths}


def run_du(paths: Sequence[Path]) -> dict[str, int]:
    """Run du -sk over the paths and return {path text: bytes} for the ones it reported."""
    command = ["du", "-sk", "--", *(str(path) for path in paths)]
    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    sizes_by_text: dict[str, int] = {}
    for line in completed.stdout.splitlines():
        kilobytes_text, _, path_text = line.partition("\t")
        sizes_by_text[path_text] = int(kilobytes_text) * 1024
    return sizes_by_text


def resolve_size(path: Path, sizes_by_text: dict[str, int]) -> int | None:
    """Use du's answer; a path that exists but got no answer was blocked, so it is None."""
    if str(path) in sizes_by_text:
        return sizes_by_text[str(path)]
    if path.exists() or path.is_symlink():
        return None
    return 0
