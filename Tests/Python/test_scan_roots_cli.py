"""Exercise the CLI and the app's scan request against a controlled directory tree."""

import io
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from adapter_fakes import FakeScanFileSystem, FakeScanProcessRunner
from cleanup_test_support import localized
from ohmyheadroom_engine.cli import commands
from ohmyheadroom_engine.features.cleanup.catalog import ReviewRule, SafeRule
from ohmyheadroom_engine.features.cleanup.scanning.report import ScanRuntime, build_report


class ScanRootFileSystem(FakeScanFileSystem):
    def is_directory(self, path: Path) -> bool:
        if path.name == "blocked":
            raise PermissionError(path)
        return path in self.walks


class ConfigurableScanRootsCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.home = Path.home()
        self.defaults = tuple(self.home / name for name in ("Developer", ".herdr", ".t3", ".synara"))
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.workspace = Path(temporary.name).resolve()
        self.custom = (self.workspace / "Project Space", self.workspace / "Code")
        for path in self.custom:
            path.mkdir()
        cache = self.workspace / "cache"
        self.cache_entry = cache / "data"
        self.review_folder = self.workspace / "review"
        roots = (*self.defaults, *self.custom)
        self.files = ScanRootFileSystem(
            self.home,
            walks={root: [(str(root), ["node_modules"], [])] for root in roots},
            children={cache: [self.cache_entry]},
        )
        self.runner = FakeScanProcessRunner(
            "Images|1GB (10%)\nBuild Cache|2GB (10%)\nLocal Volumes|3GB (10%)",
            {
                str(self.cache_entry): 1024,
                str(self.review_folder): 2048,
                **{str(root / "node_modules"): 4096 for root in roots},
            },
        )
        self.rules = (SafeRule("cache", localized("Cache"), localized("Cache"), (cache,)),)

    def scan_fixture(self, progress=None, runtime=None):
        isolated = replace(
            runtime or ScanRuntime(), filesystem=self.files, process_runner=self.runner,
            safe_rules=self.rules,
            review_rules=(ReviewRule(localized("Review"), localized("Review"), self.review_folder),),
        )
        return build_report(progress, isolated)

    def run_cli(self, args, *, input_text="", language="en"):
        stdout, stderr = io.StringIO(), io.StringIO()
        with (
            redirect_stdout(stdout), redirect_stderr(stderr),
            patch.object(commands.sys, "stdin", io.StringIO(input_text)),
            patch.object(commands, "build_report", side_effect=self.scan_fixture),
            patch.object(commands, "disk_free_bytes", return_value=123),
        ):
            status = commands.main(args, language)
        return status, stdout.getvalue(), stderr.getvalue()

    def assert_dependency_roots(self, report_text, roots):
        categories = json.loads(report_text)["safe"]
        actual = [item["path"] for category in categories if category["key"].startswith("deps-")
                  for item in category["paths"]]
        self.assertCountEqual([str(root / "node_modules") for root in roots], actual)
        return categories

    def test_scan_root_flags_replace_defaults_in_text_and_json(self) -> None:
        flags = ["--scan-root", str(self.custom[0]), "--scan-root", str(self.custom[1])]
        for command in ([], ["scan"]):
            with self.subTest(command=command):
                status, output, error = self.run_cli([*command, *flags, "--json"])
                self.assertEqual((0, ""), (status, error))
                self.assert_dependency_roots(output, self.custom)
                status, output, error = self.run_cli([*command, *flags])
                self.assertEqual((0, ""), (status, error))
                for path in self.custom:
                    self.assertIn(str(path / "node_modules"), output)
                for root in self.defaults:
                    self.assertNotIn(f"~/{root.name}/node_modules", output)

    def test_scan_without_flag_uses_four_default_roots(self) -> None:
        home = self.workspace / "home"
        preferences = home / "Library" / "Preferences" / "local.police-scan.plist"
        preferences.parent.mkdir(parents=True)
        roots = [home / name for name in ("Developer", ".herdr", ".t3", ".synara")]
        for root in (*roots, *self.custom):
            (root / "node_modules").mkdir(exist_ok=True, parents=True)
        repository = Path(__file__).resolve().parents[2]
        env = dict(os.environ, HOME=str(home), CFFIXED_USER_HOME=str(home), PATH=os.defpath)
        for saved_roots in ([str(self.custom[0])], []):
            with self.subTest(saved_roots=saved_roots):
                preferences.write_bytes(plistlib.dumps({"dependencyScanRoots": saved_roots}))
                result = subprocess.run(
                    [sys.executable, str(repository / "cleanup.py"), "scan", "--json"],
                    env=env, text=True, capture_output=True, timeout=10,
                )
                self.assertEqual((0, ""), (result.returncode, result.stderr))
                self.assert_dependency_roots(result.stdout, roots)

    def test_invalid_scan_root_exits_before_reporting(self) -> None:
        file = self.workspace / "file"
        file.touch()
        missing = self.workspace / "missing"
        blocked = self.workspace / "blocked"
        blocked.mkdir()
        for value in (None, file, missing, blocked):
            with self.subTest(value=value):
                flags = ["--scan-root"] if value is None else ["--scan-root", str(value)]
                # Deny the read even when the test runner has elevated privileges.
                next_scan = commands.os.scandir
                def scan(path):
                    if Path(path) == blocked:
                        raise PermissionError(path)
                    return next_scan(path)
                with patch.object(commands.os, "scandir", side_effect=scan):
                    status, output, error = self.run_cli(["scan", *flags, "--json"])
                self.assertEqual((2, ""), (status, output))
                self.assertIn("--scan-root" if value is None else str(value), error)
        self.assertEqual([], self.runner.commands)

    def test_help_describes_repeating_scan_roots(self) -> None:
        for language, usage in (
            ("en", "Repeat to replace the default scan roots for this run."),
            ("pt", "Repita para substituir as pastas padrão desta varredura."),
        ):
            with self.subTest(language=language):
                status, output, error = self.run_cli(["--help"], language=language)
                self.assertEqual((0, ""), (status, error))
                self.assertIn(f"scan --scan-root {'PASTA' if language == 'pt' else 'FOLDER'}", output)
                self.assertIn(usage, output)

    def test_app_scan_uses_saved_roots(self) -> None:
        roots = (self.custom[0], self.defaults[1])
        status, output, error = self.run_cli(
            ["scan", "--json", "--scan-roots-stdin"], input_text=json.dumps(list(map(str, roots))),
        )
        self.assertEqual((0, ""), (status, error))
        self.assert_dependency_roots(output, roots)

    def test_app_scan_with_empty_roots_keeps_other_categories(self) -> None:
        status, output, error = self.run_cli(["scan", "--json", "--scan-roots-stdin"], input_text="[]")
        self.assertEqual((0, ""), (status, error))
        categories = self.assert_dependency_roots(output, ())
        cache = next(category for category in categories if category["key"] == "cache")
        self.assertEqual([{"path": str(self.cache_entry), "size_bytes": 1024}], cache["paths"])
        docker = next(category for category in categories if category["key"] == "docker-prune")
        self.assertEqual(3_000_000_000, docker["size_bytes"])
        self.assertEqual(
            [(str(self.review_folder), 2048), (None, 3_000_000_000)],
            [(item["folder"], item["size_bytes"]) for item in json.loads(output)["review"]],
        )

    def test_app_scan_skips_unavailable_roots(self) -> None:
        roots = (self.workspace / "blocked", self.workspace / "missing", self.custom[0])
        status, output, error = self.run_cli(
            ["scan", "--json", "--scan-roots-stdin"], input_text=json.dumps(list(map(str, roots))),
        )
        self.assertEqual((0, ""), (status, error))
        self.assert_dependency_roots(output, (self.custom[0],))
