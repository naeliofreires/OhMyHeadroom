"""Measure filesystem paths for cleanup categories."""

from collections.abc import Sequence
from pathlib import Path

from police_scan_engine.features.cleanup.catalog import HOME
from police_scan_engine.features.cleanup.cleanup_types import Category, SizedPath
from police_scan_engine.i18n import Localized
from police_scan_engine.platform.filesystem import FileSystem
from police_scan_engine.platform.processes import ProcessRunner


def children_of(folder: Path, filesystem: FileSystem | None = None) -> list[Path]:
    """Return direct children, or none when inaccessible. Example: ``children_of(folder)``."""
    return (filesystem or FileSystem(HOME)).children(folder)


def sized_paths(
    paths: Sequence[Path],
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
) -> list[SizedPath]:
    """Pair paths with sizes, biggest first. Example: ``sized_paths(paths, fs, runner)``."""
    sizes = measure_bytes(paths, filesystem, process_runner)
    sized = [SizedPath(path=path, size_bytes=size or 0) for path, size in sizes.items()]
    return sorted(sized, key=lambda item: item.size_bytes, reverse=True)


def make_category(
    key: str,
    label: Localized,
    note: Localized,
    paths: list[SizedPath],
    commands: tuple[tuple[str, ...], ...] = (),
) -> Category:
    """Build a category from measured paths. Example: ``make_category(key, label, note, paths)``."""
    return Category(
        key=key,
        label=label,
        note=note,
        size_bytes=sum(item.size_bytes for item in paths),
        paths=tuple(paths),
        commands=commands,
    )


def measure_bytes(
    paths: Sequence[Path],
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
) -> dict[Path, int | None]:
    """Return byte sizes, preserving None for unreadable paths. Example: ``measure_bytes(paths)``."""
    if not paths:
        return {}
    sizes_by_text = run_du(paths, process_runner)
    return {path: resolve_size(path, sizes_by_text, filesystem) for path in paths}


def run_du(
    paths: Sequence[Path], process_runner: ProcessRunner | None = None
) -> dict[str, int]:
    """Run one ``du`` batch. Example: ``run_du(paths, fake_runner)``."""
    command = ["du", "-sk", "--", *(str(path) for path in paths)]
    completed = (process_runner or ProcessRunner()).run(command)
    sizes_by_text: dict[str, int] = {}
    for line in completed.stdout.splitlines():
        kilobytes_text, _, path_text = line.partition("\t")
        sizes_by_text[path_text] = int(kilobytes_text) * 1024
    return sizes_by_text


def resolve_size(
    path: Path,
    sizes_by_text: dict[str, int],
    filesystem: FileSystem | None = None,
) -> int | None:
    """Use ``du`` output, preserving None for blocked paths. Example: ``resolve_size(path, sizes)``."""
    if str(path) in sizes_by_text:
        return sizes_by_text[str(path)]
    adapter = filesystem or FileSystem(HOME)
    if adapter.exists(path) or adapter.is_symlink(path):
        return None
    return 0
