"""Named fakes shared by adapter regression tests."""

from collections.abc import Iterator
from pathlib import Path

from police_scan_engine.platform.filesystem import FileSystem


class FakeCompletedProcess:
    """Controlled process result for scan and Docker adapter checks."""

    def __init__(self, stdout: str = "", returncode: int = 0) -> None:
        self.stdout = stdout
        self.stderr = ""
        self.returncode = returncode


class FakeScanProcessRunner:
    """Return deterministic Docker and du output without starting processes."""

    def __init__(self, docker_output: str, du_sizes: dict[str, int]) -> None:
        self.docker_output = docker_output
        self.du_sizes = du_sizes
        self.commands: list[tuple[str, ...]] = []

    def run(self, command: tuple[str, ...]) -> FakeCompletedProcess:
        """Record a command and return its configured output."""
        self.commands.append(command)
        if command[0] == "docker":
            return FakeCompletedProcess(self.docker_output)
        output = "\n".join(
            f"{size // 1024}\t{path}" for path, size in self.du_sizes.items()
        )
        return FakeCompletedProcess(output + "\n")


class FakeScanFileSystem(FileSystem):
    """Filesystem fake for configured directories, walks, and free space."""

    def __init__(
        self,
        home: Path,
        walks: dict[Path, list[tuple[str, list[str], list[str]]]] | None = None,
        children: dict[Path, list[Path]] | None = None,
        free: int = 123,
    ) -> None:
        super().__init__(home)
        self.walks = walks or {}
        self.child_map = children or {}
        self.free = free

    def free_bytes(self) -> int:
        """Return configured free space."""
        return self.free

    def is_directory(self, _path: Path) -> bool:
        """Treat configured roots and folders as directories."""
        return True

    def walk(self, root: Path) -> Iterator[tuple[str, list[str], list[str]]]:
        """Yield a fresh copy of the configured walk entries."""
        return iter(
            [
                (current, list(dirs), list(files))
                for current, dirs, files in self.walks.get(root, [])
            ]
        )

    def children(self, folder: Path) -> list[Path]:
        """Return configured direct children without touching the host filesystem."""
        return list(self.child_map.get(folder, []))

    def exists(self, _path: Path) -> bool:
        """Treat measured paths as existing so missing-size behavior is testable."""
        return True


class FakeDeletionFileSystem(FileSystem):
    """Filesystem fake recording deletion operations and path resolution."""

    def __init__(self, home: Path) -> None:
        super().__init__(home)
        self.directories: set[Path] = set()
        self.symlinks: set[Path] = set()
        self.resolved: dict[Path, Path] = {}
        self.operations: list[tuple[str, Path]] = []

    def is_directory(self, path: Path) -> bool:
        """Return configured directory status."""
        return path in self.directories

    def is_symlink(self, path: Path) -> bool:
        """Return configured symlink status."""
        return path in self.symlinks

    def resolve(self, path: Path) -> Path:
        """Return configured resolution or the path itself."""
        return self.resolved.get(path, path)

    def remove_tree(self, path: Path) -> None:
        """Record directory-tree removal."""
        self.operations.append(("remove_tree", path))

    def unlink(self, path: Path) -> None:
        """Record file or symlink removal."""
        self.operations.append(("unlink", path))
