"""JSON contracts crossing the process boundary."""

import json
from dataclasses import asdict
from pathlib import Path

from headroom_engine.i18n import Localized
from headroom_engine.features.cleanup.cleanup_types import (
    Category,
    Report,
    SizedPath,
)


def report_to_json(report: Report) -> str:
    """Serialize a scan report using the wire format consumed by Swift."""
    return json.dumps(asdict(report), default=str, ensure_ascii=False)


def categories_from_json(text: str) -> tuple[Category, ...]:
    """Parse all selected categories before any cleanup side effect starts."""
    decoded: object = json.loads(text)
    if not isinstance(decoded, list):
        raise ValueError(
            f"invalid plan: expected a list of categories, got {decoded!r}"
        )
    return tuple(category_from_value(value) for value in decoded)


def category_from_value(value: object) -> Category:
    """Validate and build one selected category from decoded JSON."""
    raw = as_mapping(value, "a category")
    return Category(
        key=read_text(raw, "key"),
        label=read_localized(raw, "label"),
        note=read_localized(raw, "note"),
        size_bytes=read_int(raw, "size_bytes"),
        paths=tuple(sized_path_from_value(item) for item in read_list(raw, "paths")),
        commands=tuple(command_from_value(item) for item in read_list(raw, "commands")),
    )


def sized_path_from_value(value: object) -> SizedPath:
    """Reject relative paths before constructing a cleanup plan."""
    raw = as_mapping(value, "a path with path and size_bytes")
    path_text = read_text(raw, "path")
    if not path_text.startswith("/"):
        raise ValueError(f"relative path refused: {path_text!r}; use an absolute path")
    return SizedPath(path=Path(path_text), size_bytes=read_int(raw, "size_bytes"))


def command_from_value(value: object) -> tuple[str, ...]:
    """Validate an executable command represented as string arguments."""
    if not isinstance(value, list) or not all(isinstance(part, str) for part in value):
        raise ValueError(f"invalid command: expected a list of strings, got {value!r}")
    return tuple(value)


def as_mapping(value: object, expected: str) -> dict[str, object]:
    """Require a JSON object and include its actual value in failures."""
    if not isinstance(value, dict):
        raise ValueError(f"expected {expected}, got {value!r}")
    return value


def read_text(raw: dict[str, object], field: str) -> str:
    """Read a required string field."""
    value = raw.get(field)
    if not isinstance(value, str):
        raise ValueError(f"field '{field}' must be a string, got {value!r}")
    return value


def read_int(raw: dict[str, object], field: str) -> int:
    """Read a required integer field, excluding booleans."""
    value = raw.get(field)
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError(f"field '{field}' must be an integer, got {value!r}")
    return value


def read_list(raw: dict[str, object], field: str) -> list[object]:
    """Read a required JSON list field."""
    value = raw.get(field)
    if not isinstance(value, list):
        raise ValueError(f"field '{field}' must be a list, got {value!r}")
    return value


def read_localized(raw: dict[str, object], field: str) -> Localized:
    """Read a bilingual text object from the wire contract."""
    nested = as_mapping(raw.get(field), f"field '{field}' with pt and en strings")
    return Localized(pt=read_text(nested, "pt"), en=read_text(nested, "en"))
