"""Apply validated cleanup categories while preserving CLI output semantics."""

from enum import Enum
from pathlib import Path

from ohmyheadroom_engine.features.cleanup.catalog import HOME
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category
from ohmyheadroom_engine.features.cleanup.execution.trash import move_to_trash
from ohmyheadroom_engine.i18n import Localized
from ohmyheadroom_engine.platform.filesystem import FileSystem
from ohmyheadroom_engine.platform.processes import ProcessRunner

CLEANING = Localized(pt="Limpando: {label}", en="Cleaning: {label}")
COMMAND_OK = Localized(pt="  ok: {command}", en="  ok: {command}")
COMMAND_SKIPPED = Localized(
    pt="  pulei '{command}': {error}", en="  skipped '{command}': {error}"
)
COMMAND_FAILED = Localized(
    pt="  falhou ({code}): {command} - {stderr}",
    en="  failed ({code}): {command} - {stderr}",
)
PATH_OUTSIDE_HOME = Localized(
    pt="  pulei {path}: fora da pasta do usuário",
    en="  skipped {path}: outside the user folder",
)
PATH_NOT_DELETED = Localized(
    pt="  não foi possível remover {path}: {error}",
    en="  could not remove {path}: {error}",
)
PATH_MOVED = Localized(
    pt="  movido para a Lixeira: {path}",
    en="  moved to the Trash: {path}",
)
PATH_NOT_MOVED = Localized(
    pt="  não foi possível mover para a Lixeira: {path}: {error}",
    en="  could not move to the Trash: {path}: {error}",
)


class DeleteMode(Enum):
    """How selected paths leave the disk. Example: ``DeleteMode.TRASH``."""

    TRASH = "trash"
    PERMANENT = "permanent"


def clean_category(
    category: Category,
    language: str,
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
    mode: DeleteMode = DeleteMode.TRASH,
) -> None:
    """Run commands before paths. Example: ``clean_category(category, 'en', fs, runner)``."""
    print(f"\n{CLEANING.render(language, label=category.label.for_language(language))}")
    for command in category.commands:
        if process_runner is None:
            run_command(command, language)
        else:
            run_command(command, language, process_runner)
    for sized in category.paths:
        remove_path(sized.path, language, filesystem, mode)


def run_command(
    command: tuple[str, ...],
    language: str,
    process_runner: ProcessRunner | None = None,
) -> None:
    """Run and report one command. Example: ``run_command(command, 'en', runner)``."""
    command_text = " ".join(command)
    try:
        completed = (process_runner or ProcessRunner()).run(command)
    except OSError as error:
        print(COMMAND_SKIPPED.render(language, command=command_text, error=str(error)))
        return
    if completed.returncode == 0:
        print(COMMAND_OK.render(language, command=command_text))
        return
    print_command_failure(
        command_text, completed.returncode, completed.stderr, language
    )


def print_command_failure(command: str, code: int, stderr: str, language: str) -> None:
    """Render a command failure. Example: ``print_command_failure('du', 1, 'locked', 'en')``."""
    print(
        COMMAND_FAILED.render(
            language, code=str(code), command=command, stderr=stderr.strip()
        )
    )


def remove_path(
    path: Path,
    language: str,
    filesystem: FileSystem | None = None,
    mode: DeleteMode = DeleteMode.TRASH,
) -> None:
    """Guard, then move to the Trash or delete. Example: ``remove_path(path, 'en', fs)``."""
    adapter = filesystem or FileSystem(HOME)
    if not is_inside_home(path, adapter.home, adapter):
        print(PATH_OUTSIDE_HOME.render(language, path=str(path)))
        return
    if mode is DeleteMode.PERMANENT:
        delete_permanently(path, language, adapter)
        return
    move_to_trash_reporting(path, language, adapter)


def delete_permanently(path: Path, language: str, adapter: FileSystem) -> None:
    """Delete one path for good and report a failure. Example: ``delete_permanently(path, 'en', fs)``."""
    try:
        delete_entry(path, adapter)
    except OSError as error:
        print(PATH_NOT_DELETED.render(language, path=str(path), error=str(error)))


def move_to_trash_reporting(path: Path, language: str, adapter: FileSystem) -> None:
    """Move one path to the Trash; a failure leaves it in place. Example: ``move_to_trash_reporting(path, 'en', fs)``."""
    try:
        move_to_trash(path, adapter)
    except OSError as error:
        print(PATH_NOT_MOVED.render(language, path=str(path), error=str(error)))
        return
    print(PATH_MOVED.render(language, path=str(path)))


def delete_entry(path: Path, filesystem: FileSystem | None = None) -> None:
    """Remove a tree or unlink one entry. Example: ``delete_entry(path, fake_fs)``."""
    adapter = filesystem or FileSystem(HOME)
    if adapter.is_directory(path) and not adapter.is_symlink(path):
        adapter.remove_tree(path)
        return
    adapter.unlink(path)


def is_inside_home(
    path: Path, home: Path = HOME, filesystem: FileSystem | None = None
) -> bool:
    """Check the resolved parent guard. Example: ``is_inside_home(path, home, fs)``."""
    adapter = filesystem or FileSystem(home)
    parent_resolved = adapter.resolve(path.parent)
    return parent_resolved.is_relative_to(adapter.resolve(home)) and path != home
