"""Domain types exchanged by cleanup scanning and execution."""

from dataclasses import dataclass
from pathlib import Path

from ohmyheadroom_engine.i18n import Localized


@dataclass(frozen=True)
class SizedPath:
    """A path with the bytes it occupies on disk."""

    path: Path
    size_bytes: int


@dataclass(frozen=True)
class Category:
    """One safe-to-clean line of the report, with paths and commands."""

    key: str
    label: Localized
    note: Localized
    size_bytes: int
    paths: tuple[SizedPath, ...] = ()
    commands: tuple[tuple[str, ...], ...] = ()


@dataclass(frozen=True)
class ReviewLine:
    """A measured folder the user decides about and the app never deletes."""

    label: Localized
    note: Localized
    size_bytes: int | None
    folder: Path | None


@dataclass(frozen=True)
class Report:
    """Everything found by a scan: safe categories, review lines, and free space."""

    safe: tuple[Category, ...]
    review: tuple[ReviewLine, ...]
    free_bytes: int


__all__ = ["Category", "Report", "ReviewLine", "SizedPath"]
