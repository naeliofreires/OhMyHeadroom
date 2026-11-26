"""Regression tests for the host filesystem adapter's move and folder creation."""

import stat
import tempfile
import unittest
from pathlib import Path

from ohmyheadroom_engine.platform.filesystem import FileSystem


class FilesystemAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.workspace = tempfile.TemporaryDirectory()
        self.root = Path(self.workspace.name)
        self.filesystem = FileSystem(self.root)

    def tearDown(self) -> None:
        self.workspace.cleanup()

    def test_move_renames_entry_to_destination(self) -> None:
        source = self.root / "cache"
        destination = self.root / "moved"
        source.mkdir()

        self.filesystem.move(source, destination)

        self.assertFalse(source.exists())
        self.assertTrue(destination.is_dir())

    def test_make_directory_creates_private_folder(self) -> None:
        folder = self.root / "Trash"

        self.filesystem.make_directory(folder)

        self.assertTrue(folder.is_dir())
        self.assertEqual(0o700, stat.S_IMODE(folder.stat().st_mode))

    def test_make_directory_accepts_existing_folder(self) -> None:
        folder = self.root / "Trash"
        folder.mkdir()

        self.filesystem.make_directory(folder)

        self.assertTrue(folder.is_dir())


if __name__ == "__main__":
    unittest.main()
