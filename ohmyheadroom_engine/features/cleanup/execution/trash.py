"""Move cleanup targets into the macOS Trash instead of deleting them."""

from pathlib import Path

from ohmyheadroom_engine.platform.filesystem import FileSystem


def unique_trash_destination(name: str, trash_dir: Path, filesystem: FileSystem) -> Path:
    """Return a free Trash path for a name. Example: ``unique_trash_destination('cache', trash, fs)``."""
    first_choice = trash_dir / name
    if not filesystem.exists(first_choice):
        return first_choice
    entry = Path(name)
    number = 2
    while True:
        candidate = trash_dir / f"{entry.stem} {number}{entry.suffix}"
        if not filesystem.exists(candidate):
            return candidate
        number += 1
