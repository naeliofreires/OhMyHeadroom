"""Apply validated cleanup categories while preserving CLI output semantics."""

from pathlib import Path

from headroom_engine.features.cleanup.catalog import HOME
from headroom_engine.features.cleanup.cleanup_types import Category
from headroom_engine.i18n import Localized
from headroom_engine.platform.filesystem import FileSystem
from headroom_engine.platform.processes import ProcessRunner

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
    pt="  não consegui apagar {path}: {error}", en="  could not delete {path}: {error}"
)


def clean_category(
    category: Category,
    language: str,
    filesystem: FileSystem | None = None,
    process_runner: ProcessRunner | None = None,
) -> None:
    """Run commands before paths. Example: ``clean_category(category, 'en', fs, runner)``."""
    print(f"\n{CLEANING.render(language, label=category.label.for_language(language))}")
    for command in category.commands:
        if process_runner is None:
            run_command(command, language)
        else:
            run_command(command, language, process_runner)
    for sized in category.paths:
        if filesystem is None:
            remove_path(sized.path, language)
        else:
            remove_path(sized.path, language, filesystem)


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
    path: Path, language: str, filesystem: FileSystem | None = None
) -> None:
    """Guard then delete one path. Example: ``remove_path(path, 'en', fake_fs)``."""
    adapter = filesystem or FileSystem(HOME)
    if not is_inside_home(path, adapter.home, adapter):
        print(PATH_OUTSIDE_HOME.render(language, path=str(path)))
        return
    try:
        delete_entry(path, adapter)
    except OSError as error:
        print(PATH_NOT_DELETED.render(language, path=str(path), error=str(error)))


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
