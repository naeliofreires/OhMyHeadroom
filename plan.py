"""JSON boundary between the Python engine and the menu bar app.

`scan --json` prints a Report. The app sends back the categories the user picked,
on stdin, to `apagar`. Field names are snake_case, so the Swift Codable structs
read them with convertFromSnakeCase.
"""

import json
from dataclasses import asdict
from pathlib import Path

from i18n import Localized
from scan import Category, Report, SizedPath


def report_to_json(report: Report) -> str:
    """Serialize a report for the app. Paths become plain strings.

    Example: text = report_to_json(build_report())
    """
    return json.dumps(asdict(report), default=str, ensure_ascii=False)


def categories_from_json(text: str) -> tuple[Category, ...]:
    """Parse the categories sent by the app. A malformed plan raises before anything is deleted.

    Example: categories = categories_from_json('[{"key": "logs", "label": "...", ...}]')
    """
    decoded: object = json.loads(text)
    if not isinstance(decoded, list):
        raise ValueError(
            f"plano inválido: esperado uma lista de categorias, veio {decoded!r}"
        )
    return tuple(category_from_value(item) for item in decoded)


def category_from_value(value: object) -> Category:
    """Build one Category from a decoded JSON object, checking every field."""
    raw = as_mapping(value, "uma categoria")
    return Category(
        key=read_text(raw, "key"),
        label=read_localized(raw, "label"),
        note=read_localized(raw, "note"),
        size_bytes=read_int(raw, "size_bytes"),
        paths=tuple(sized_path_from_value(item) for item in read_list(raw, "paths")),
        commands=tuple(command_from_value(item) for item in read_list(raw, "commands")),
    )


def sized_path_from_value(value: object) -> SizedPath:
    """Build one SizedPath, rejecting relative paths so a bad plan cannot delete from the cwd."""
    raw = as_mapping(value, "um caminho com path e size_bytes")
    path_text = read_text(raw, "path")
    if not path_text.startswith("/"):
        raise ValueError(f"caminho relativo recusado: {path_text!r}; use caminho absoluto")
    return SizedPath(path=Path(path_text), size_bytes=read_int(raw, "size_bytes"))


def command_from_value(value: object) -> tuple[str, ...]:
    """A cleanup command is a list of strings, e.g. ["docker", "image", "prune"]."""
    if not isinstance(value, list) or not all(isinstance(part, str) for part in value):
        raise ValueError(
            f"comando inválido: esperado lista de textos, veio {value!r}"
        )
    return tuple(value)


def as_mapping(value: object, expected: str) -> dict[str, object]:
    """Require a JSON object; the error names what was expected."""
    if not isinstance(value, dict):
        raise ValueError(f"esperado {expected}, veio {value!r}")
    return value


def read_text(raw: dict[str, object], field: str) -> str:
    """Read a required text field."""
    value = raw.get(field)
    if not isinstance(value, str):
        raise ValueError(f"campo '{field}' deve ser texto, veio {value!r}")
    return value


def read_int(raw: dict[str, object], field: str) -> int:
    """Read a required integer field; booleans are refused even though Python counts them as ints."""
    value = raw.get(field)
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError(f"campo '{field}' deve ser inteiro, veio {value!r}")
    return value


def read_list(raw: dict[str, object], field: str) -> list[object]:
    """Read a required list field."""
    value = raw.get(field)
    if not isinstance(value, list):
        raise ValueError(f"campo '{field}' deve ser lista, veio {value!r}")
    return value


def read_localized(raw: dict[str, object], field: str) -> Localized:
    """Read a text field that carries both languages, e.g. {"pt": "...", "en": "..."}."""
    nested = as_mapping(raw.get(field), f"campo '{field}' com os textos pt e en")
    return Localized(pt=read_text(nested, "pt"), en=read_text(nested, "en"))
