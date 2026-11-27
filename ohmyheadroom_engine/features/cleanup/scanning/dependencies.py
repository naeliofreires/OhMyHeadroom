"""Discovery and categorization of rebuildable dependency directories."""

from collections.abc import Iterator, Sequence
from pathlib import Path

from ohmyheadroom_engine.features.cleanup.catalog import (
    DEPENDENCY_DIR_NAMES,
    DEPENDENCY_SCAN_ROOTS,
    HOME,
)
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, SizedPath
from ohmyheadroom_engine.features.cleanup.scanning.measurements import (
    make_category,
    sized_paths,
)
from ohmyheadroom_engine.i18n import Localized
from ohmyheadroom_engine.platform.filesystem import FileSystem
from ohmyheadroom_engine.platform.processes import ProcessRunner

DEPENDENCY_NOTE_PROJECTS = Localized(
    pt="Reinstale com npm install / uv sync antes de rodar o projeto de novo.",
    en="Reinstall with npm install / uv sync before running the project again.",
)
DEPENDENCY_NOTE_WORKTREES = Localized(
    pt="Worktrees de agentes e do Herdr. Se um agente estiver rodando nele agora, reinstale depois.",
    en="Agent and Herdr worktrees. If an agent is running in one right now, reinstall afterwards.",
)
WORKTREE_DEPENDENCIES_LABEL = Localized(
    pt="Dependências e builds em worktrees (agentes, Herdr)",
    en="Dependencies and builds in worktrees (agents, Herdr)",
)
PROJECT_DEPENDENCIES_LABEL = Localized(
    pt="Dependências e builds em projetos",
    en="Dependencies and builds in projects",
)
DEPENDENCY_SCAN_LABEL = Localized(
    pt="Dependências e builds (node_modules, .venv)",
    en="Dependencies and builds (node_modules, .venv)",
)


def build_dependency_categories(
    roots: Sequence[Path] = DEPENDENCY_SCAN_ROOTS,
    names: Sequence[str] = DEPENDENCY_DIR_NAMES,
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
) -> list[Category]:
    """Find and split dependency folders. Example: ``build_dependency_categories(roots, names)``."""
    dependency_dirs = collect_dependency_dirs(roots, names, filesystem)
    sized = sized_paths(dependency_dirs, filesystem, process_runner)
    worktree_items, project_items = partition_dependency_paths(sized)
    return make_dependency_categories(worktree_items, project_items)


def make_dependency_categories(
    worktree_items: list[SizedPath], project_items: list[SizedPath]
) -> list[Category]:
    """Build the stable category pair. Example: ``make_dependency_categories([], [])``."""
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


def collect_dependency_dirs(
    roots: Sequence[Path], names: Sequence[str], filesystem: FileSystem | None
) -> list[Path]:
    """Collect dependency directories from roots. Example: ``collect_dependency_dirs(roots, names, fs)``."""
    return list({
        path: None
        for root in dict.fromkeys(roots)
        for path in find_dependency_dirs(root, names, filesystem)
    })


def partition_dependency_paths(
    paths: Sequence[SizedPath],
) -> tuple[list[SizedPath], list[SizedPath]]:
    """Split paths by worktree ownership. Example: ``partition_dependency_paths(paths)``."""
    return (
        [item for item in paths if is_worktree_path(item.path)],
        [item for item in paths if not is_worktree_path(item.path)],
    )


def find_dependency_dirs(
    root: Path,
    dependency_dir_names: Sequence[str] = DEPENDENCY_DIR_NAMES,
    filesystem: FileSystem | None = None,
) -> list[Path]:
    """Walk a root without descending into dependencies. Example: ``find_dependency_dirs(root, names, fs)``."""
    adapter = filesystem or FileSystem(HOME)
    try:
        if not adapter.is_directory(root):
            return []
    except OSError:
        return []
    return walk_dependency_dirs(adapter.walk(root), dependency_dir_names)


def walk_dependency_dirs(
    walker: Iterator[tuple[str, list[str], list[str]]],
    dependency_dir_names: Sequence[str],
) -> list[Path]:
    """Collect and prune dependency folders. Example: ``walk_dependency_dirs(walker, names)``."""
    found: list[Path] = []
    for current_text, subdir_names, _file_names in walker:
        found.extend(
            Path(current_text, name)
            for name in subdir_names
            if name in dependency_dir_names
        )
        # Pruning in place stops os.walk from entering folders already recorded.
        subdir_names[:] = [
            name for name in subdir_names if is_walkable(name, dependency_dir_names)
        ]
    return found


def is_walkable(name: str, dependency_dir_names: Sequence[str]) -> bool:
    """Skip recorded dependencies and git metadata. Example: ``is_walkable('.git', names)``."""
    return name not in dependency_dir_names and name != ".git"


def is_worktree_path(path: Path) -> bool:
    """Return whether a path is under ``worktrees``. Example: ``is_worktree_path(path)``."""
    return "worktrees" in path.parts
