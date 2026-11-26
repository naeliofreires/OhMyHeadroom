"""Regression tests for the clean and apply commands' --permanent flag."""

import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from adapter_fakes import FakeTrashFileSystem
from cleanup_test_support import FIXTURES, localized, operations_for_report
from ohmyheadroom_engine.cli import commands
from ohmyheadroom_engine.cli.commands import CleanupOperations
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, Report, SizedPath
from ohmyheadroom_engine.features.cleanup.execution import runner
from ohmyheadroom_engine.features.cleanup.execution.runner import DeleteMode

HOME = Path("/home/test")
CACHE_PATH = HOME / "Library" / "Caches" / "app"


def cache_report() -> Report:
    """One safe category holding one cache folder. Example: ``cache_report()``."""
    category = Category(
        "app-caches",
        localized("Caches"),
        localized("Regenerable"),
        1200,
        paths=(SizedPath(CACHE_PATH, 1200),),
    )
    return Report(safe=(category,), review=(), free_bytes=0)


def cache_operations(files: FakeTrashFileSystem) -> CleanupOperations:
    """Operations whose apply runs the real runner against a fake filesystem."""
    return operations_for_report(
        cache_report(),
        lambda: 0,
        lambda category, language, mode: runner.clean_category(
            category, language, files, None, mode
        ),
    )


class TrashCliTests(unittest.TestCase):
    def test_permanent_flag_deletes_selected_paths(self) -> None:
        files = FakeTrashFileSystem(HOME)

        with redirect_stdout(io.StringIO()):
            code = commands.main(["clean", "--yes", "--permanent"], "en", cache_operations(files))

        self.assertEqual(0, code)
        self.assertEqual([("unlink", CACHE_PATH)], files.removals)

    def test_permanent_flag_never_touches_trash(self) -> None:
        files = FakeTrashFileSystem(HOME)

        with redirect_stdout(io.StringIO()):
            commands.main(["clean", "--yes", "--permanent"], "en", cache_operations(files))

        self.assertEqual([], files.moves)
        self.assertEqual([], files.created_directories)

    def test_clean_without_flag_moves_to_trash(self) -> None:
        files = FakeTrashFileSystem(HOME)

        with redirect_stdout(io.StringIO()):
            commands.main(["clean", "--yes"], "en", cache_operations(files))

        self.assertEqual([(CACHE_PATH, HOME / ".Trash" / "app")], files.moves)
        self.assertEqual([], files.removals)

    def test_apply_passes_permanent_mode_to_each_category(self) -> None:
        modes: list[DeleteMode] = []
        operations = operations_for_report(
            cache_report(),
            lambda: 0,
            lambda _category, _language, mode: modes.append(mode),
        )
        plan = (FIXTURES / "cleanup-plan.json").read_text()

        with redirect_stdout(io.StringIO()), patch.object(
            commands.sys, "stdin", io.StringIO(plan)
        ):
            commands.main(["apply", "--permanent"], "en", operations)

        self.assertTrue(modes)
        self.assertEqual([DeleteMode.PERMANENT] * len(modes), modes)


if __name__ == "__main__":
    unittest.main()
