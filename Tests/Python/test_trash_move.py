"""Regression tests for moving one path into the home Trash."""

import tempfile
import unittest
from pathlib import Path

from adapter_fakes import FakeTrashFileSystem
from ohmyheadroom_engine.features.cleanup.execution.trash import move_to_trash
from ohmyheadroom_engine.platform.filesystem import FileSystem

HOME = Path("/home/test")


class TrashMoveTests(unittest.TestCase):
    def test_moves_path_into_home_trash_without_removing(self) -> None:
        filesystem = FakeTrashFileSystem(HOME)
        path = HOME / "project" / "node_modules"

        destination = move_to_trash(path, filesystem)

        self.assertEqual(HOME / ".Trash" / "node_modules", destination)
        self.assertEqual([(path, destination)], filesystem.moves)
        self.assertEqual([], filesystem.removals)

    def test_creates_missing_trash_folder_before_moving(self) -> None:
        filesystem = FakeTrashFileSystem(HOME)

        move_to_trash(HOME / "cache", filesystem)

        self.assertEqual([HOME / ".Trash"], filesystem.created_directories)

    def test_symbolic_link_is_moved_as_link_and_target_stays(self) -> None:
        with tempfile.TemporaryDirectory() as workspace:
            home = Path(workspace)
            target = home / "real-cache"
            link = home / "cache-link"
            target.mkdir()
            link.symlink_to(target, target_is_directory=True)

            destination = move_to_trash(link, FileSystem(home))

            self.assertTrue(destination.is_symlink())
            self.assertTrue(target.is_dir())


if __name__ == "__main__":
    unittest.main()
