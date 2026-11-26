"""Regression tests for filesystem deletion seams and path guards."""

import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from adapter_fakes import FakeDeletionFileSystem
from headroom_engine.features.cleanup.execution.runner import (
    delete_entry,
    is_inside_home,
    remove_path,
)


class PathSafetyTests(unittest.TestCase):
    def test_directory_uses_remove_tree(self) -> None:
        home = Path("/home/test")
        filesystem = FakeDeletionFileSystem(home)
        path = home / "cache"
        filesystem.directories.add(path)

        delete_entry(path, filesystem)

        self.assertEqual([("remove_tree", path)], filesystem.operations)

    def test_symlinked_directory_uses_unlink(self) -> None:
        home = Path("/home/test")
        filesystem = FakeDeletionFileSystem(home)
        path = home / "link"
        filesystem.directories.add(path)
        filesystem.symlinks.add(path)

        delete_entry(path, filesystem)

        self.assertEqual([("unlink", path)], filesystem.operations)

    def test_file_uses_unlink(self) -> None:
        home = Path("/home/test")
        filesystem = FakeDeletionFileSystem(home)
        path = home / "file"

        delete_entry(path, filesystem)

        self.assertEqual([("unlink", path)], filesystem.operations)

    def test_outside_home_and_home_itself_are_refused(self) -> None:
        home = Path("/home/test")
        filesystem = FakeDeletionFileSystem(home)
        output = io.StringIO()
        with redirect_stdout(output):
            remove_path(Path("/tmp/outside"), "en", filesystem)
            remove_path(home, "en", filesystem)

        self.assertEqual([], filesystem.operations)
        self.assertEqual(2, output.getvalue().count("outside the user folder"))

    def test_resolved_parent_outside_home_is_refused(self) -> None:
        home = Path("/home/test")
        filesystem = FakeDeletionFileSystem(home)
        path = home / "link" / "file"
        filesystem.resolved[path.parent] = Path("/tmp/outside")

        self.assertFalse(is_inside_home(path, home, filesystem))
        output = io.StringIO()
        with redirect_stdout(output):
            remove_path(path, "en", filesystem)

        self.assertEqual([], filesystem.operations)
        self.assertIn("outside the user folder", output.getvalue())


if __name__ == "__main__":
    unittest.main()
