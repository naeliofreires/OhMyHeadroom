"""Move cleanup targets into the macOS Trash instead of deleting them."""

from pathlib import Path

from ohmyheadroom_engine.platform.filesystem import FileSystem

TRASH_FOLDER_NAME = ".Trash"


def unique_trash_destination(name: str, trash_dir: Path, filesystem: FileSystem) -> Path:
    """Return a free Trash path for a name. Example: ``unique_trash_destination('cache', trash, fs)``."""
    first_choice = trash_dir / name
    if not filesystem.lexists(first_choice):
        return first_choice
    entry = Path(name)
    number = 2
    while True:
        candidate = trash_dir / f"{entry.stem} {number}{entry.suffix}"
        if not filesystem.lexists(candidate):
            return candidate
        number += 1


def move_to_trash(path: Path, filesystem: FileSystem) -> Path:
    """Move one path into the home Trash and return where it landed. Example: ``move_to_trash(path, fs)``."""
    trash_dir = filesystem.home / TRASH_FOLDER_NAME
    filesystem.make_directory(trash_dir)
    destination = unique_trash_destination(path.name, trash_dir, filesystem)
    filesystem.move(path, destination)
    return destination
