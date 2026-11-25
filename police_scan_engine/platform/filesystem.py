"""Filesystem adapter used by scanning and cleanup execution."""

import shutil
import os
from collections.abc import Iterator
from pathlib import Path


class FileSystem:
    """Provide filesystem effects behind a replaceable adapter.

    Example: filesystem = FileSystem(Path.home()); free = filesystem.free_bytes()
    """

    def __init__(self, home: Path) -> None:
        self.home = home

    def free_bytes(self) -> int:
        """Return free bytes on the volume containing the configured home."""
        return shutil.disk_usage(self.home).free

    def children(self, folder: Path) -> list[Path]:
        """List a folder's direct children, returning none when inaccessible."""
        try:
            return sorted(folder.iterdir())
        except OSError:
            return []

    def walk(self, root: Path) -> Iterator[tuple[str, list[str], list[str]]]:
        """Walk a root using the host filesystem implementation."""
        return os.walk(root)

    def exists(self, path: Path) -> bool:
        """Report whether a path exists."""
        return path.exists()

    def is_symlink(self, path: Path) -> bool:
        """Report whether a path is a symbolic link."""
        return path.is_symlink()

    def is_directory(self, path: Path) -> bool:
        """Report whether a path is a directory."""
        return path.is_dir()

    def resolve(self, path: Path) -> Path:
        """Resolve a path using the host filesystem semantics."""
        return path.resolve()

    def remove_tree(self, path: Path) -> None:
        """Remove a directory tree without following symlinks."""
        shutil.rmtree(path)

    def unlink(self, path: Path) -> None:
        """Remove one file or symlink, ignoring an already absent path."""
        path.unlink(missing_ok=True)
