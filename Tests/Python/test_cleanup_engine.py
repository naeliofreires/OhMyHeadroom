"""Behavior and contract tests for the feature-based Python engine."""

import io
import json
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from ohmyheadroom_engine.cli import commands
from ohmyheadroom_engine.features.cleanup import contracts
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, SizedPath
from ohmyheadroom_engine.features.cleanup.execution import runner
from ohmyheadroom_engine.features.cleanup.scanning import docker, measurements
from ohmyheadroom_engine.features.cleanup.scanning.progress import ProgressReporter
from ohmyheadroom_engine.features.cleanup.scanning.report import build_report
from ohmyheadroom_engine.i18n import normalize_language
from cleanup_test_support import (
    FIXTURES,
    FakeCompletedProcess,
    FakeCleanupSink,
    FakeCommandRunner,
    FakeFileSystem,
    FakeOutputRunner,
    FakeScanRunner,
    ObservingFreeReader,
    category_to_payload,
    failure_category,
    failure_operations,
    localized,
    operations_for_report,
    plan_with_path,
    report_from_payload,
    scan_runtime,
)


class ContractTests(unittest.TestCase):
    def test_report_fixture_round_trips_through_serializer(self) -> None:
        payload = json.loads((FIXTURES / "scan-report.json").read_text())
        report = contracts.report_to_json(report_from_payload(payload))
        self.assertEqual(json.loads(report), payload)

    def test_plan_fixture_parses_all_categories_before_returning(self) -> None:
        text = (FIXTURES / "cleanup-plan.json").read_text()
        categories = contracts.categories_from_json(text)
        self.assertEqual(
            ("app-caches",), tuple(category.key for category in categories)
        )

    def test_relative_path_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "relative path refused"):
            contracts.categories_from_json(plan_with_path("relative/cache"))

    def test_invalid_plan_is_rejected_before_any_category_is_built(self) -> None:
        with self.assertRaisesRegex(ValueError, "expected a list"):
            contracts.categories_from_json("{}")

    def test_parser_rejects_boolean_sizes_and_non_string_commands(self) -> None:
        payload = json.loads((FIXTURES / "cleanup-plan.json").read_text())
        payload[0]["size_bytes"] = True
        with self.assertRaisesRegex(ValueError, "must be an integer"):
            contracts.categories_from_json(json.dumps(payload))
        payload = json.loads((FIXTURES / "cleanup-plan.json").read_text())
        payload[0]["commands"] = [["docker", 1]]
        with self.assertRaisesRegex(ValueError, "invalid command"):
            contracts.categories_from_json(json.dumps(payload))


class CommandTests(unittest.TestCase):
    def test_unknown_command_returns_two_without_scanning(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output), patch.object(
            commands, "build_report", side_effect=AssertionError("scan called")
        ):
            self.assertEqual(2, commands.main(["unknown"], "en"))
        self.assertIn("Commands: scan", output.getvalue())

    def test_eof_is_a_negative_confirmation(self) -> None:
        with patch("builtins.input", side_effect=EOFError):
            self.assertFalse(commands.read_yes("?"))

    def test_keyboard_interrupt_returns_130(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output), patch.object(
            commands, "main", side_effect=KeyboardInterrupt
        ):
            with patch.object(commands, "resolve_language", return_value="en"):
                self.assertEqual(130, commands.run_main())
        self.assertIn("Cancelled", output.getvalue())

    def test_plain_scan_uses_report_and_json_scan_uses_serializer(self) -> None:
        fake_report = report_from_payload(
            json.loads((FIXTURES / "scan-report.json").read_text())
        )
        output = io.StringIO()
        with redirect_stdout(output), patch.object(
            commands, "build_report", return_value=fake_report
        ), patch.object(commands, "print_report") as render:
            self.assertEqual(0, commands.main([], "en"))
            render.assert_called_once()
        json_output = io.StringIO()
        with redirect_stdout(json_output), patch.object(
            commands, "build_report", return_value=fake_report
        ):
            self.assertEqual(0, commands.main(["scan", "--json"], "en"))
        self.assertIn("Measuring", output.getvalue())
        self.assertIn('"safe"', json_output.getvalue())

    def test_scan_reads_free_space_after_review_lines_render(self) -> None:
        report = report_from_payload(
            json.loads((FIXTURES / "scan-report.json").read_text())
        )
        output = io.StringIO()
        reader = ObservingFreeReader(output)
        operations = operations_for_report(report, reader.read)
        with redirect_stdout(output):
            self.assertEqual(0, commands.run_scan("en", operations))
        self.assertEqual(1, reader.calls)
        self.assertTrue(reader.saw_review_before_footer)

    def test_clean_yes_applies_every_safe_category(self) -> None:
        fake_report = report_from_payload(
            json.loads((FIXTURES / "scan-report.json").read_text())
        )
        output = io.StringIO()
        with redirect_stdout(output), patch.object(
            commands, "build_report", return_value=fake_report
        ), patch.object(commands, "disk_free_bytes", return_value=10), patch.object(
            commands, "clean_category"
        ) as clean:
            self.assertEqual(0, commands.run_clean(True, "en"))
        self.assertEqual(2, clean.call_count)
        self.assertIn("Freed in this run", output.getvalue())

    def test_apply_invalid_trailing_category_has_no_effect(self) -> None:
        payload = json.loads((FIXTURES / "cleanup-plan.json").read_text())
        payload.append({"key": "broken"})
        error = io.StringIO()
        with redirect_stderr(error), patch.object(commands, "clean_category") as clean:
            self.assertEqual(1, commands.run_apply(json.dumps(payload), "en"))
        clean.assert_not_called()
        self.assertIn("Plan refused", error.getvalue())

    def test_apply_continues_after_command_failure_and_returns_zero(self) -> None:
        fake_process = FakeCommandRunner(returncode=1)
        fake_files = FakeFileSystem(Path("/Users/example"))
        operations = failure_operations(
            fake_files,
            fake_process,
        )
        output = io.StringIO()
        with redirect_stdout(output):
            code = commands.run_apply(
                json.dumps([category_to_payload(failure_category())]),
                "en",
                operations,
            )
        self.assertEqual(0, code)
        self.assertEqual([("fake", "cleanup")], fake_process.commands)
        self.assertEqual([Path("/Users/example/cache")], fake_files.removed)
        self.assertIn("failed (1)", output.getvalue())


class ExecutionTests(unittest.TestCase):
    def test_commands_run_before_paths_and_path_failure_does_not_stop(self) -> None:
        category = Category(
            key="fake",
            label=localized("Fake"),
            note=localized("Fake"),
            size_bytes=1,
            paths=(SizedPath(Path("/Users/example/cache"), 1),),
            commands=(("fake", "cleanup"),),
        )
        sink = FakeCleanupSink()
        output = io.StringIO()
        with redirect_stdout(output), patch.object(
            runner, "run_command", sink.command
        ), patch.object(runner, "remove_path", sink.path):
            runner.clean_category(category, "en")
        self.assertEqual(["command", "path"], sink.events)
        self.assertIn("Cleaning: Fake", output.getvalue())

    def test_outside_home_path_is_skipped(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output), patch.object(
            runner, "delete_entry", side_effect=AssertionError("delete called")
        ):
            runner.remove_path(Path("/tmp/outside"), "en")
        self.assertIn("outside the user folder", output.getvalue())

    def test_process_runner_and_filesystem_are_injected(self) -> None:
        fake_process = FakeCommandRunner(returncode=1)
        fake_files = FakeFileSystem(Path("/Users/example"))
        output = io.StringIO()
        with redirect_stdout(output):
            runner.run_command(("fake",), "en", fake_process)
            runner.remove_path(Path("/Users/example/file"), "en", fake_files)
        self.assertEqual([("fake",)], fake_process.commands)
        self.assertEqual([Path("/Users/example/file")], fake_files.removed)
        self.assertIn("failed (1)", output.getvalue())

    def test_command_and_path_failures_are_logged_without_raising(self) -> None:
        class FailingFileSystem(FakeFileSystem):
            """Named fake that rejects one unlink operation."""

            def unlink(self, _path: Path) -> None:
                raise OSError("locked")

        output = io.StringIO()
        with redirect_stdout(output):
            runner.run_command(("fake",), "en", FakeCommandRunner(returncode=1))
            runner.remove_path(
                Path("/Users/example/file"),
                "en",
                FailingFileSystem(Path("/Users/example")),
            )
        self.assertIn("could not remove", output.getvalue())


class ProgressTests(unittest.TestCase):
    def test_progress_fixture_matches_reporter_output(self) -> None:
        stream = io.StringIO()
        reporter = ProgressReporter(stream)
        reporter.start(2)
        reporter.step(localized("Caches"), "~/Library/Caches")
        self.assertEqual((FIXTURES / "progress.jsonl").read_text(), stream.getvalue())

    def test_measurement_uses_fake_process_output_and_preserves_missing_as_none(
        self,
    ) -> None:
        fake = FakeOutputRunner("4\t/Users/example/a\n")
        sizes = measurements.measure_bytes(
            (Path("/Users/example/a"), Path("/tmp")), None, fake
        )
        self.assertEqual(4096, sizes[Path("/Users/example/a")])
        self.assertIsNone(sizes[Path("/tmp")])

    def test_docker_unavailable_is_omitted(self) -> None:
        class UnavailableRunner:
            """Named fake for an unavailable Docker executable."""

            def run(self, _command: tuple[str, ...]) -> FakeCompletedProcess:
                raise OSError("docker unavailable")

        self.assertIsNone(docker.docker_reclaimable_bytes(UnavailableRunner()))

    def test_full_scan_uses_runtime_fakes_and_custom_catalog(self) -> None:
        result = build_report(runtime=scan_runtime())
        self.assertEqual(
            ("cache", "deps-worktrees", "deps-projects"),
            tuple(item.key for item in result.safe),
        )
        self.assertEqual(4096, result.safe[0].size_bytes)
        self.assertIsNone(result.review[0].size_bytes)
        self.assertEqual(77, result.free_bytes)


class FormattingTests(unittest.TestCase):
    def test_language_and_size_formatting(self) -> None:
        from ohmyheadroom_engine.cli.presentation import format_size

        self.assertEqual("pt", normalize_language("pt_BR.UTF-8"))
        self.assertEqual("1,2 KB", format_size(1234, "pt"))
        self.assertEqual("no access", format_size(None, "en"))


if __name__ == "__main__":
    unittest.main()
