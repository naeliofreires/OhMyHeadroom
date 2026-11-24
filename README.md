# Police Scan

Police Scan finds files your Mac can recreate, such as caches, downloaded packages,
Docker images, dependencies, and build artifacts. It estimates how much space each
category could free and deletes only the categories you select.

- **Police Scan.app**: a SwiftUI menu bar app with scan progress and a confirmation step.
- **`cleanup.py`**: the command-line interface, using the same engine as the app.

## How it works

The app runs `python3 cleanup.py scan --json --progress` to get a scan report on
stdout and progress events on stderr. After you confirm a selection, it sends
the selected categories as JSON on stdin to `python3 cleanup.py apply`. The
Python engine performs all deletions.

## Project layout

| Path | Purpose |
|---|---|
| `cleanup.py` | CLI entry point: `scan`, `clean`, and `apply` |
| `scan.py` | Measures disk usage in parallel and builds the report; does not delete anything |
| `targets.py` | Lists safe cleanup categories and review-only paths |
| `plan.py` | Serializes reports and validates cleanup plans before deletion |
| `progress.py` | Sends scan progress events to the app |
| `i18n.py` | Selects the language and handles localized text |
| `Package.swift`, `Sources/PoliceScan/` | SwiftUI menu bar app |
| `build-app.sh`, `Info.plist` | Build and installation script, and app bundle metadata |
| `Tools/make-icon.swift`, `Resources/AppIcon.icns` | Icon generator and app icon |
| `Localization/` | English and Brazilian Portuguese app strings |

## Categories

**Safe to delete** (apps or tools recreate the files; dependencies are unchecked by default):

| Category | Contents |
|---|---|
| App and browser caches | Contents of `~/Library/Caches` |
| Downloaded packages | `~/.npm`, the pnpm store, and the Yarn cache |
| Cursor and Claude caches | Extension and interface caches only |
| Old logs | `~/Library/Logs` |
| Unused Docker images and build cache | `docker image prune -a` and `docker builder prune`; volumes are left alone |
| Worktree dependencies | `node_modules`, `.venv`, `.next`, `.turbo`, and `__pycache__` in agent and Herdr worktrees |
| Project dependencies | The same folders in primary project checkouts |

**Review only** (measured and listed, never deleted): Claude VM image, Docker virtual
disk, unused Docker volumes, Codex history, `~/.local/share`, Cursor state, Herdr
worktrees, MeetingMind and WhatsApp data, Downloads, Movies, and Trash.

## Requirements

- macOS 26 or later for the app's Liquid Glass interface.
- Python 3.10 or later (tested with Python 3.14). The app looks for `python3` in
  `/opt/homebrew/bin` or `/usr/local/bin`.
- The Swift toolchain to build the app. Command Line Tools suffice; full Xcode is not required.
- Docker is optional; Docker entries are omitted when Docker is unavailable.

## Usage

From the repository root:

```sh
python3 cleanup.py              # Show the report without deleting anything
python3 cleanup.py clean        # Ask before cleaning each safe category
python3 cleanup.py clean --yes  # Clean every safe category without asking
```

Use `--lang pt` or `--lang en` to override the shell locale. Command names are the same in both languages.

App integration commands:

```sh
python3 cleanup.py scan --json             # Write the JSON report to stdout
python3 cleanup.py scan --json --progress  # Also write progress events to stderr
python3 cleanup.py apply --lang en         # Read a cleanup plan from stdin and apply it
```

In **Police Scan**, click **Scan**, select categories, then choose **Delete selected…**.
The app follows your system language.

## Build and install the app

Run this from the repository root:

```sh
./build-app.sh
```

The script builds and signs the app, then installs it at `~/Applications/Police Scan.app`.
The app looks for `cleanup.py` in `~/Developer/PoliceScan`; if your checkout lives
elsewhere, update `CleanupEngine.locate()` before building.

To regenerate the icon:

```sh
mkdir -p Resources && swiftc Tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Resources
```

## Safety and permissions

- The engine rejects paths outside the home folder and rejects malformed plans
  and relative paths before deleting anything.
- The engine never deletes review-only categories. In interactive mode, an empty
  response or closed stdin counts as no.
- macOS protects Downloads and Trash. Grant **Full Disk Access** to Police Scan
  under **System Settings → Privacy & Security** if those folders show as
  inaccessible. If you use the CLI, grant access to your terminal instead.
- The app is signed ad hoc. macOS may ask for permission again after a rebuild.

## Known limitations

- `du` has no timeout. A stalled folder can block the scan.
- `apply` checks the plan's format but does not restrict which commands it can
  contain. Only use it with trusted input.
- `/tmp` and the user's temporary directory are not scanned.
- There is no automated test suite.

## Development

- Keep filenames, identifiers, and comments in English.
- Add category and review text in `targets.py` or `scan.py` as `Localized(pt=..., en=...)`.
- Add SwiftUI text to `Localization/*.lproj/Localizable.strings`. Use the English
  text as the key and provide a Brazilian Portuguese translation in `pt-BR.lproj`.
