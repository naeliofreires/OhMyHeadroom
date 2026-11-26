"""Named fakes and builders shared by the Python cleanup behavior tests."""

import io
import json
from collections.abc import Callable, Iterator, Mapping
from pathlib import Path
from typing import cast

from headroom_engine.cli import commands
from headroom_engine.features.cleanup import contracts
from headroom_engine.features.cleanup.catalog import ReviewRule, SafeRule
from headroom_engine.features.cleanup.cleanup_types import (
    Category,
    Report,
    ReviewLine,
    SizedPath,
)
from headroom_engine.features.cleanup.execution import runner
from headroom_engine.features.cleanup.scanning.report import ScanRuntime
from headroom_engine.i18n import Localized
from headroom_engine.platform.filesystem import FileSystem

FIXTURES = Path(__file__).parents[1] / "Fixtures"


class FakeCompletedProcess:
    """Completed-process value used by command tests."""

    def __init__(self, returncode: int = 0, stderr: str = "", stdout: str = "") -> None:
        self.returncode = returncode
        self.stderr = stderr
        self.stdout = stdout


class FakeCommandRunner:
    """Named process fake that records commands without invoking the OS."""

    def __init__(self, returncode: int = 0) -> None:
        self.returncode = returncode
        self.commands: list[tuple[str, ...]] = []

    def run(self, command: tuple[str, ...], **_kwargs: object) -> FakeCompletedProcess:
        self.commands.append(command)
        return FakeCompletedProcess(self.returncode, "fake failure")


class FakeOutputRunner:
    """Named process fake returning controlled stdout for measurement tests."""

    def __init__(self, stdout: str, returncode: int = 0) -> None:
        self.stdout = stdout
        self.returncode = returncode

    def run(self, _command: tuple[str, ...]) -> FakeCompletedProcess:
        return FakeCompletedProcess(self.returncode, stdout=self.stdout)


class FakeFileSystem(FileSystem):
    """Named filesystem fake for free-space and deletion tests."""

    def __init__(self, home: Path, free: int = 10) -> None:
        super().__init__(home)
        self.free = free
        self.removed: list[Path] = []

    def free_bytes(self) -> int:
        return self.free

    def remove_tree(self, path: Path) -> None:
        self.removed.append(path)

    def unlink(self, path: Path) -> None:
        self.removed.append(path)

    def is_directory(self, _path: Path) -> bool:
        return False

    def is_symlink(self, _path: Path) -> bool:
        return False

    def resolve(self, path: Path) -> Path:
        return path


class FakeScanFileSystem(FakeFileSystem):
    """Named scan filesystem fake with deterministic children and roots."""

    def children(self, folder: Path) -> list[Path]:
        return [folder / "a"] if folder.name == "cache" else []

    def exists(self, _path: Path) -> bool:
        return True

    def walk(self, _root: Path) -> Iterator[tuple[str, list[str], list[str]]]:
        return iter(())


class FakeScanRunner:
    """Named scan process fake for Docker and du commands."""

    def run(self, command: tuple[str, ...]) -> FakeCompletedProcess:
        if command[0] == "docker":
            return FakeCompletedProcess(returncode=1)
        return FakeCompletedProcess(stdout="4\t/runtime/cache/a\n")


class FakeCleanupSink:
    """Named side-effect fake used to verify command-before-path ordering."""

    def __init__(self) -> None:
        self.events: list[str] = []

    def command(self, _command: tuple[str, ...], _language: str) -> None:
        self.events.append("command")

    def path(self, _path: Path, _language: str) -> None:
        self.events.append("path")


class ObservingFreeReader:
    """Named free-space fake that records the report-rendering order."""

    def __init__(self, stream: io.StringIO) -> None:
        self.stream = stream
        self.calls = 0
        self.saw_review_before_footer = False

    def read(self) -> int:
        self.calls += 1
        output = self.stream.getvalue()
        self.saw_review_before_footer = (
            "Review manually" in output and "Free space now" not in output
        )
        return 10


def localized(text: str) -> Localized:
    """Build bilingual test text. Example: ``localized('Cache')``."""
    return Localized(pt=text, en=text)


def operations_for_report(
    report: Report,
    free_reader: Callable[[], int],
    apply: Callable[[Category, str], None] | None = None,
) -> commands.CleanupOperations:
    """Build injected operations around one fake report. Example: ``operations_for_report(report, read)``."""
    applier = apply or (lambda _category, _language: None)
    return commands.CleanupOperations(
        scan=lambda: report,
        scan_with_progress=lambda _stream: report,
        free_bytes=free_reader,
        apply=applier,
    )


def failure_category() -> Category:
    """Build a command-plus-path category. Example: ``failure_category()``."""
    return Category(
        key="fake",
        label=localized("Fake"),
        note=localized("Fake"),
        size_bytes=1,
        paths=(SizedPath(Path("/Users/example/cache"), 1),),
        commands=(("fake", "cleanup"),),
    )


def failure_operations(
    files: FakeFileSystem, process: FakeCommandRunner
) -> commands.CleanupOperations:
    """Build apply operations using named failure fakes. Example: ``failure_operations(fs, runner)``."""
    report = report_from_payload(
        json.loads((FIXTURES / "scan-report.json").read_text())
    )
    return operations_for_report(
        report,
        lambda: 10,
        lambda category, language: runner.clean_category(
            category, language, files, process
        ),
    )


def scan_runtime() -> ScanRuntime:
    """Build a tiny complete scan runtime. Example: ``build_report(runtime=scan_runtime())``."""
    return ScanRuntime(
        filesystem=FakeScanFileSystem(Path("/runtime"), free=77),
        process_runner=FakeScanRunner(),
        safe_rules=(cache_rule(),),
        review_rules=(review_rule(),),
        dependency_roots=(),
        dependency_dir_names=("node_modules",),
    )


def cache_rule() -> SafeRule:
    """Build the minimal safe rule used by a fake scan. Example: ``cache_rule()``."""
    return SafeRule(
        "cache", localized("Cache"), localized("Cache"), (Path("/runtime/cache"),)
    )


def review_rule() -> ReviewRule:
    """Build the minimal review rule used by a fake scan. Example: ``review_rule()``."""
    return ReviewRule(localized("Review"), localized("Review"), Path("/runtime/review"))


def report_from_payload(payload: Mapping[str, object]) -> Report:
    """Build a domain report from fixture data. Example: ``report_from_payload(payload)``."""
    safe = tuple(category_from_payload(value) for value in payload["safe"])
    review = tuple(review_from_payload(value) for value in payload["review"])
    return Report(safe=safe, review=review, free_bytes=payload["free_bytes"])


def category_from_payload(value: object) -> Category:
    """Build one category from fixture data. Example: ``category_from_payload(value)``."""
    raw = cast(Mapping[str, object], value)
    labels = cast(Mapping[str, object], raw["label"])
    notes = cast(Mapping[str, object], raw["note"])
    paths = cast(list[Mapping[str, object]], raw["paths"])
    commands_value = cast(list[list[str]], raw["commands"])
    return Category(
        key=cast(str, raw["key"]),
        label=localized_pair(labels),
        note=localized_pair(notes),
        size_bytes=cast(int, raw["size_bytes"]),
        paths=tuple(
            SizedPath(Path(cast(str, item["path"])), cast(int, item["size_bytes"]))
            for item in paths
        ),
        commands=tuple(tuple(command) for command in commands_value),
    )


def review_from_payload(value: object) -> ReviewLine:
    """Build one review line from fixture data. Example: ``review_from_payload(value)``."""
    raw = cast(Mapping[str, object], value)
    return ReviewLine(
        label=localized_pair(cast(Mapping[str, object], raw["label"])),
        note=localized_pair(cast(Mapping[str, object], raw["note"])),
        size_bytes=cast(int, raw["size_bytes"]),
        folder=Path(cast(str, raw["folder"])),
    )


def localized_pair(value: Mapping[str, object]) -> Localized:
    """Build bilingual text from fixture data. Example: ``localized_pair(labels)``."""
    return Localized(pt=cast(str, value["pt"]), en=cast(str, value["en"]))


def plan_with_path(path: str) -> str:
    """Return the plan fixture with a path substituted. Example: ``plan_with_path('relative')``."""
    payload = json.loads((FIXTURES / "cleanup-plan.json").read_text())
    payload[0]["paths"][0]["path"] = path
    return json.dumps(payload)


def category_to_payload(category: Category) -> dict[str, object]:
    """Convert a category to the cleanup contract. Example: ``category_to_payload(category)``."""
    return json.loads(
        contracts.report_to_json(
            report_from_payload(
                {"safe": [category_as_fixture(category)], "review": [], "free_bytes": 0}
            )
        )
    )["safe"][0]


def category_as_fixture(category: Category) -> dict[str, object]:
    """Build serializer-compatible category data. Example: ``category_as_fixture(category)``."""
    return {
        "key": category.key,
        "label": {"pt": category.label.pt, "en": category.label.en},
        "note": {"pt": category.note.pt, "en": category.note.en},
        "size_bytes": category.size_bytes,
        "paths": [
            {"path": str(item.path), "size_bytes": item.size_bytes}
            for item in category.paths
        ],
        "commands": [list(command) for command in category.commands],
    }
