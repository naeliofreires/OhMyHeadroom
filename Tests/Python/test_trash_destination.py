"""Regression tests for picking a free name inside the Trash."""

import unittest
from pathlib import Path

from adapter_fakes import FakeTrashFileSystem
from ohmyheadroom_engine.features.cleanup.execution.trash import unique_trash_destination

TRASH = Path("/home/test/.Trash")


class TrashDestinationTests(unittest.TestCase):
    def test_returns_plain_name_when_free(self) -> None:
        filesystem = FakeTrashFileSystem(Path("/home/test"))

        destination = unique_trash_destination("node_modules", TRASH, filesystem)

        self.assertEqual(TRASH / "node_modules", destination)

    def test_names_taken_entry_with_next_free_number(self) -> None:
        filesystem = FakeTrashFileSystem(Path("/home/test"))
        filesystem.existing.add(TRASH / "cache")

        first_retry = unique_trash_destination("cache", TRASH, filesystem)
        filesystem.existing.add(TRASH / "cache 2")
        second_retry = unique_trash_destination("cache", TRASH, filesystem)

        self.assertEqual(TRASH / "cache 2", first_retry)
        self.assertEqual(TRASH / "cache 3", second_retry)

    def test_keeps_extension_after_the_number(self) -> None:
        filesystem = FakeTrashFileSystem(Path("/home/test"))
        filesystem.existing.add(TRASH / "pnpm.store")

        destination = unique_trash_destination("pnpm.store", TRASH, filesystem)

        self.assertEqual(TRASH / "pnpm 2.store", destination)

    def test_name_without_extension_gets_number_at_end(self) -> None:
        filesystem = FakeTrashFileSystem(Path("/home/test"))
        filesystem.existing.add(TRASH / ".npm")

        destination = unique_trash_destination(".npm", TRASH, filesystem)

        self.assertEqual(TRASH / ".npm 2", destination)


if __name__ == "__main__":
    unittest.main()
