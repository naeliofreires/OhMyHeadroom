"""What the cleanup engine inspects, and how far each folder can be trusted.

Plain data: scan.py measures these entries and cleanup.py removes them. Every label
and note is written in Portuguese and English.
To watch another folder, add a rule here instead of adding a branch to the code.
"""

from dataclasses import dataclass
from pathlib import Path

from i18n import Localized

HOME: Path = Path.home()
APP_SUPPORT: Path = HOME / "Library" / "Application Support"
# macOS privacy protection (TCC) blocks reads of these folders until the app or terminal is allowed.
PRIVACY_HINT = Localized(
    pt="Sem permissão de leitura: dê Acesso Total ao Disco ao Police Scan "
    "ou ao app de terminal (Ajustes > Privacidade e Segurança).",
    en="No read permission: give Full Disk Access to Police Scan or your terminal app "
    "(System Settings > Privacy & Security).",
)


@dataclass(frozen=True)
class SafeRule:
    """A folder whose contents the owning app or tool rebuilds on its own."""

    key: str
    label: Localized
    note: Localized
    folders: tuple[Path, ...]


@dataclass(frozen=True)
class ReviewRule:
    """A folder that may hold data you want to keep, so it is measured and listed only."""

    label: Localized
    note: Localized
    folder: Path


# WHY: only the contents of each folder are removed, never the folder itself,
# so apps find the directory layout they expect on their next launch.
SAFE_RULES: tuple[SafeRule, ...] = (
    SafeRule(
        key="app-caches",
        label=Localized(
            pt="Caches de apps e navegadores (~/Library/Caches)",
            en="App and browser caches (~/Library/Caches)",
        ),
        note=Localized(
            pt="Apps recriam sozinhos. Feche os apps antes. O primeiro uso depois fica mais lento.",
            en="Apps rebuild them on their own. Quit the apps first. "
            "The first use afterwards is slower.",
        ),
        folders=(HOME / "Library" / "Caches",),
    ),
    SafeRule(
        key="package-caches",
        label=Localized(
            pt="Pacotes baixados: npm, pnpm, yarn",
            en="Downloaded packages: npm, pnpm, yarn",
        ),
        note=Localized(
            pt="Baixados de novo no próximo install (precisa de internet).",
            en="Downloaded again on the next install (needs internet).",
        ),
        folders=(
            HOME / ".npm",
            HOME / "Library" / "pnpm" / "store",
            HOME / ".yarn" / "berry" / "cache",
        ),
    ),
    SafeRule(
        key="editor-caches",
        label=Localized(
            pt="Cache do Cursor e do Claude",
            en="Cursor and Claude cache",
        ),
        note=Localized(
            pt="Só cache de extensões e de interface. Configurações e conversas ficam.",
            en="Only extension and interface cache. Settings and conversations stay.",
        ),
        folders=(
            APP_SUPPORT / "Cursor" / "CachedExtensionVSIXs",
            APP_SUPPORT / "Cursor" / "CachedData",
            APP_SUPPORT / "Cursor" / "Cache",
            APP_SUPPORT / "Claude" / "Cache",
            APP_SUPPORT / "Claude" / "Code Cache",
        ),
    ),
    SafeRule(
        key="logs",
        label=Localized(
            pt="Logs antigos (~/Library/Logs)",
            en="Old logs (~/Library/Logs)",
        ),
        note=Localized(
            pt="Registros de diagnóstico. Apagar não afeta nenhum app.",
            en="Diagnostic records. Deleting them does not affect any app.",
        ),
        folders=(HOME / "Library" / "Logs",),
    ),
)


# Only these are reported, never deleted: each one can hold work or history.
REVIEW_RULES: tuple[ReviewRule, ...] = (
    ReviewRule(
        label=Localized(
            pt="Imagem de VM do Claude (vm_bundles)",
            en="Claude VM image (vm_bundles)",
        ),
        note=Localized(
            pt="Usada pelo Cowork e pelos agentes. Apagar obriga novo download na próxima vez.",
            en="Used by Cowork and the agents. Deleting it forces a new download next time.",
        ),
        folder=APP_SUPPORT / "Claude" / "vm_bundles",
    ),
    ReviewRule(
        label=Localized(pt="Disco virtual do Docker", en="Docker virtual disk"),
        note=Localized(
            pt="Não encolhe só por apagar imagens. Para reduzir, use o próprio Docker Desktop.",
            en="It does not shrink just from deleting images. "
            "To reduce it, use Docker Desktop itself.",
        ),
        folder=HOME / "Library" / "Containers" / "com.docker.docker",
    ),
    ReviewRule(
        label=Localized(
            pt="Histórico e pacotes do Codex (~/.codex)",
            en="Codex history and packages (~/.codex)",
        ),
        note=Localized(
            pt="Sessões antigas do Codex. Apagar perde o histórico.",
            en="Old Codex sessions. Deleting them loses the history.",
        ),
        folder=HOME / ".codex",
    ),
    ReviewRule(
        label=Localized(
            pt="Dados de agentes (~/.local/share)",
            en="Agent data (~/.local/share)",
        ),
        note=Localized(
            pt="opencode, claude, cursor-agent, junie: binários e histórico.",
            en="opencode, claude, cursor-agent, junie: binaries and history.",
        ),
        folder=HOME / ".local" / "share",
    ),
    ReviewRule(
        label=Localized(
            pt="Estado do Cursor (User + snapshots)",
            en="Cursor state (User + snapshots)",
        ),
        note=Localized(
            pt="Workspaces e snapshots de agentes. Apagar perde o histórico local.",
            en="Workspaces and agent snapshots. Deleting them loses the local history.",
        ),
        folder=APP_SUPPORT / "Cursor",
    ),
    ReviewRule(
        label=Localized(
            pt="Worktrees do Herdr (~/.herdr)",
            en="Herdr worktrees (~/.herdr)",
        ),
        note=Localized(
            pt="Pode ter código não commitado. Confira com git status antes.",
            en="May hold uncommitted code. Check with git status first.",
        ),
        folder=HOME / ".herdr",
    ),
    ReviewRule(
        label=Localized(
            pt="App de reuniões (MeetingMind)",
            en="Meeting app (MeetingMind)",
        ),
        note=Localized(
            pt="Pode guardar gravações e transcrições.",
            en="May store recordings and transcripts.",
        ),
        folder=HOME / "Library" / "Group Containers" / "group.com.kc.shubi.meetingmind",
    ),
    ReviewRule(
        label=Localized(
            pt="WhatsApp (mídia do Mac)",
            en="WhatsApp (Mac media)",
        ),
        note=Localized(
            pt="Fotos e vídeos recebidos. Confira antes.",
            en="Photos and videos you received. Check first.",
        ),
        folder=HOME / "Library" / "Group Containers" / "group.net.whatsapp.WhatsApp.shared",
    ),
    ReviewRule(
        label=Localized(pt="Downloads", en="Downloads"),
        note=Localized(pt="Seus arquivos.", en="Your files.").with_suffix(PRIVACY_HINT),
        folder=HOME / "Downloads",
    ),
    ReviewRule(
        label=Localized(pt="Filmes (~/Movies)", en="Movies (~/Movies)"),
        note=Localized(pt="Seus vídeos. Revise manualmente.", en="Your videos. Review manually."),
        folder=HOME / "Movies",
    ),
    ReviewRule(
        label=Localized(pt="Lixeira", en="Trash"),
        note=Localized(pt="Esvazie pelo Finder.", en="Empty it from Finder.").with_suffix(
            PRIVACY_HINT
        ),
        folder=HOME / ".Trash",
    ),
)


# Build outputs and installed dependencies: all rebuildable with one install command.
DEPENDENCY_DIR_NAMES: tuple[str, ...] = (
    "node_modules",
    ".next",
    ".turbo",
    ".venv",
    "__pycache__",
)

# Where projects and agent worktrees live. Worktrees under these roots duplicate
# node_modules, which is why they are reported in their own category.
DEPENDENCY_SCAN_ROOTS: tuple[Path, ...] = (
    HOME / "Developer",
    HOME / ".herdr",
    HOME / ".t3",
    HOME / ".synara",
)
