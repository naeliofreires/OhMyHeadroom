"""Docker measurements used by the cleanup report."""

import re

from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, ReviewLine
from ohmyheadroom_engine.i18n import Localized
from ohmyheadroom_engine.platform.processes import ProcessRunner

DOCKER_DF_FORMAT = "{{.Type}}|{{.Reclaimable}}"
DOCKER_SIZE_PATTERN = re.compile(r"^([\d.]+)(B|kB|MB|GB|TB)\b")
DOCKER_UNIT_BYTES: dict[str, int] = {
    "B": 1,
    "kB": 1000,
    "MB": 1000**2,
    "GB": 1000**3,
    "TB": 1000**4,
}
# Docker reports decimal units (1 GB = 1000 MB), not the binary units du uses.
DOCKER_PRUNE_COMMANDS: tuple[tuple[str, ...], ...] = (
    ("docker", "image", "prune", "-a", "-f"),
    ("docker", "builder", "prune", "-f"),
)
DOCKER_PRUNE_LABEL = Localized(
    pt="Docker: imagens e build cache sem uso",
    en="Docker: unused images and build cache",
)
DOCKER_PRUNE_NOTE = Localized(
    pt="Imagens sem container são baixadas ou refeitas depois. Volumes NÃO são tocados.",
    en="Images without a container are downloaded or rebuilt later. Volumes are NOT touched.",
)
DOCKER_VOLUMES_LABEL = Localized(
    pt="Docker: volumes sem uso", en="Docker: unused volumes"
)
DOCKER_VOLUMES_NOTE = Localized(
    pt="Podem guardar dados de bancos. Confira com: docker volume ls -f dangling=true",
    en="They may hold database data. Check with: docker volume ls -f dangling=true",
)
DOCKER_PROBE_LABEL = Localized(
    pt="Docker: imagens e volumes", en="Docker: images and volumes"
)


def docker_reclaimable_bytes(
    process_runner: ProcessRunner | None = None,
) -> dict[str, int] | None:
    """Return Docker reclaimable bytes, or None when unavailable. Example: ``docker_reclaimable_bytes(runner)``."""
    try:
        command = ("docker", "system", "df", "--format", DOCKER_DF_FORMAT)
        completed = (process_runner or ProcessRunner()).run(command)
    except OSError:
        return None
    if completed.returncode != 0:
        return None
    return parse_docker_df(completed.stdout)


def parse_docker_df(output: str) -> dict[str, int]:
    """Parse Docker's ``Type|size`` lines. Example: ``parse_docker_df('Images|1GB')``."""
    reclaimable: dict[str, int] = {}
    for line in output.splitlines():
        type_name, _, size_text = line.partition("|")
        reclaimable[type_name] = parse_docker_size(size_text)
    return reclaimable


def parse_docker_size(text: str) -> int:
    """Convert a Docker decimal size to bytes. Example: ``parse_docker_size('1GB')``."""
    match = DOCKER_SIZE_PATTERN.match(text.strip())
    if match is None:
        raise ValueError(
            f"unrecognized Docker size: {text!r}; expected something like '2.458GB (7%)'"
        )
    return int(float(match.group(1)) * DOCKER_UNIT_BYTES[match.group(2)])


def build_docker_category(reclaimable: dict[str, int]) -> Category:
    """Build the safe Docker images/build-cache category. Example: ``build_docker_category({})``."""
    return Category(
        key="docker-prune",
        label=DOCKER_PRUNE_LABEL,
        note=DOCKER_PRUNE_NOTE,
        size_bytes=reclaimable.get("Images", 0) + reclaimable.get("Build Cache", 0),
        commands=DOCKER_PRUNE_COMMANDS,
    )


def build_docker_volume_line(reclaimable: dict[str, int]) -> ReviewLine:
    """Build the review-only Docker volumes line. Example: ``build_docker_volume_line({})``."""
    return ReviewLine(
        label=DOCKER_VOLUMES_LABEL,
        note=DOCKER_VOLUMES_NOTE,
        size_bytes=reclaimable.get("Local Volumes", 0),
        folder=None,
    )
