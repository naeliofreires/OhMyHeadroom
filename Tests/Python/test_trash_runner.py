"""Regression tests for the runner's Trash mode: moves, failures and ordering."""

import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from adapter_fakes import FakeCompletedProcess, FakeTrashFileSystem
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, SizedPath
from ohmyheadroom_engine.features.cleanup.execution.runner import (
    DeleteMode,
    clean_category,
    remove_path,
)
from ohmyheadroom_engine.i18n import Localized

HOME = Path("/home/test")


class RejectingMoveFileSystem(FakeTrashFileSystem):
    """Named fake whose moves always fail, as on a volume the Trash cannot reach."""

    def move(self, source: Path, destination: Path) -> None:
        """Refuse the move with a host-style error."""
        raise OSError("Resource busy")


class EventRecordingFileSystem(FakeTrashFileSystem):
    """Named fake that appends each move to a shared event log."""

    def __init__(self, home: Path, events: list[str]) -> None:
        super().__init__(home)
        self.events = events

    def move(self, source: Path, destination: Path) -> None:
        """Record the move in order with the command events."""
        self.events.append("path")
        super().move(source, destination)


class EventRecordingRunner:
    """Named process fake that appends each command to a shared event log."""

    def __init__(self, events: list[str]) -> None:
        self.events = events

    def run(self, _command: tuple[str, ...]) -> FakeCompletedProcess:
        """Record the command and report success."""
        self.events.append("command")
        return FakeCompletedProcess(0)


class TrashRunnerTests(unittest.TestCase):
    def test_default_mode_moves_folder_into_trash(self) -> None:
        filesystem = FakeTrashFileSystem(HOME)
        path = HOME / "project" / "node_modules"

        with redirect_stdout(io.StringIO()):
            remove_path(path, "en", filesystem)

        self.assertEqual([(path, HOME / ".Trash" / "node_modules")], filesystem.moves)
        self.assertEqual([], filesystem.removals)

    def test_failed_move_keeps_path_and_reports_it(self) -> None:
        filesystem = RejectingMoveFileSystem(HOME)
        path = HOME / "cache"
        output = io.StringIO()

        with redirect_stdout(output):
            remove_path(path, "en", filesystem, DeleteMode.TRASH)

        self.assertEqual([], filesystem.removals)
        self.assertIn("could not move to the Trash", output.getvalue())

    def test_moved_path_prints_trash_line(self) -> None:
        filesystem = FakeTrashFileSystem(HOME)
        path = HOME / "cache"
        output = io.StringIO()

        with redirect_stdout(output):
            remove_path(path, "en", filesystem)

        self.assertIn(f"moved to the Trash: {path}", output.getvalue())

    def test_path_outside_home_is_not_moved(self) -> None:
        filesystem = FakeTrashFileSystem(HOME)
        output = io.StringIO()

        with redirect_stdout(output):
            remove_path(Path("/tmp/outside"), "en", filesystem)

        self.assertEqual([], filesystem.moves)
        self.assertIn("outside the user folder", output.getvalue())

    def test_commands_run_before_trash_moves(self) -> None:
        events: list[str] = []
        category = Category(
            key="fake",
            label=Localized(pt="Falso", en="Fake"),
            note=Localized(pt="Nota", en="Note"),
            size_bytes=0,
            paths=(SizedPath(HOME / "cache", 0),),
            commands=(("fake-command",),),
        )

        with redirect_stdout(io.StringIO()):
            clean_category(
                category,
                "en",
                EventRecordingFileSystem(HOME, events),
                EventRecordingRunner(events),
                DeleteMode.TRASH,
            )

        self.assertEqual(["command", "path"], events)


if __name__ == "__main__":
    unittest.main()
