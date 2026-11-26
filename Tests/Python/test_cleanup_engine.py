"""Behavior and contract tests for the feature-based Python engine."""

import io
import json
import unittest
from collections.abc import Sequence
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from unittest.mock import Mock, patch

from ohmyheadroom_engine.cli import commands
from ohmyheadroom_engine.features.cleanup import contracts
from ohmyheadroom_engine.features.cleanup.cleanup_types import Category, CleanupResult, SizedPath
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

    def test_cleanup_result_fixture_matches_serializer(self) -> None:
        payload = json.loads((FIXTURES / "cleanup-result.json").read_text())
        result = CleanupResult(before_bytes=1200, after_bytes=200, log="done\n")
        self.assertEqual(payload, json.loads(contracts.cleanup_result_to_json(result)))
        payload["after_bytes"] = None
        unavailable = replace(result, after_bytes=None)
        self.assertEqual(payload, json.loads(contracts.cleanup_result_to_json(unavailable)))

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
    def test_help_prints_localized_usage_without_running_commands(self) -> None:
        for argv, language, heading in (
            (["--help"], "en", "Usage:"),
            (["-h"], "pt", "Uso:"),
            (["scan", "--json", "--help"], "en", "Usage:"),
            (["clean", "--yes", "--help"], "en", "Usage:"),
            (["apply", "--help"], "en", "Usage:"),
        ):
            with self.subTest(argv=argv, language=language):
                output = io.StringIO()
                with redirect_stdout(output), patch.object(
                    commands, "build_report", side_effect=AssertionError("scan called")
                ), patch.object(commands.sys, "stdin") as stdin:
                    stdin.read.side_effect = AssertionError("plan read")
                    self.assertEqual(0, commands.main(argv, language))
                self.assertTrue(output.getvalue().startswith(heading))
                self.assertIn("python3 cleanup.py", output.getvalue())
                self.assertIn("apply --json", output.getvalue())

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
        report = report_from_payload(json.loads((FIXTURES / "scan-report.json").read_text()))
        for json_output in (False, True):
            with self.subTest(json_output=json_output):
                error, output = io.StringIO(), io.StringIO()
                clean, free_reader, measure = Mock(), Mock(), Mock()
                operations = operations_for_report(report, free_reader, clean, measure)
                with redirect_stderr(error), redirect_stdout(output):
                    code = commands.run_apply(
                        json.dumps(payload), "en", operations, json_output=json_output
                    )
                self.assertEqual(1, code)
                free_reader.assert_not_called()
                clean.assert_not_called()
                measure.assert_not_called()
                self.assertEqual("", output.getvalue())
                self.assertIn("Plan refused", error.getvalue())

    def test_apply_json_measures_only_the_plan_after_execution(self) -> None:
        report = report_from_payload(json.loads((FIXTURES / "scan-report.json").read_text()))
        plan = (FIXTURES / "cleanup-plan.json").read_text()
        events: list[str] = []
        free_values = iter((9000, 9500))

        def free_bytes() -> int:
            events.append("free")
            return next(free_values)

        def apply(category: Category, language: str) -> None:
            events.append(category.key)
            print(f"Cleaning: {category.label.for_language(language)}")

        def measure(categories: Sequence[Category]) -> int:
            self.assertEqual((report.safe[0],), tuple(categories))
            events.append("measure")
            return 200

        operations = operations_for_report(report, free_bytes, apply, measure)
        output = io.StringIO()
        with redirect_stdout(output), patch.object(commands.sys, "stdin", io.StringIO(plan)):
            self.assertEqual(0, commands.main(["apply", "--json"], "en", operations))

        result = json.loads(output.getvalue())
        self.assertEqual({"before_bytes", "after_bytes", "log"}, result.keys())
        self.assertEqual(1200, result["before_bytes"])
        self.assertEqual(200, result["after_bytes"])
        self.assertIn("Cleaning: App caches", result["log"])
        self.assertIn("Freed in this run: 500.0 B", result["log"])
        self.assertEqual(["free", "app-caches", "free", "measure"], events)

    def test_apply_continues_after_command_failure_and_returns_zero(self) -> None:
        fake_process = FakeCommandRunner(returncode=1)
        fake_files = FakeFileSystem(Path("/Users/example"))
        measure = Mock()
        operations = replace(failure_operations(fake_files, fake_process), measure_selected=measure)
        output = io.StringIO()
        plan = json.dumps([category_to_payload(failure_category())])
        with redirect_stdout(output), patch.object(commands.sys, "stdin", io.StringIO(plan)):
            code = commands.main(["apply"], "en", operations)
        measure.assert_not_called()
        self.assertEqual(0, code)
        self.assertEqual([("fake", "cleanup")], fake_process.commands)
        self.assertEqual([Path("/Users/example/cache")], fake_files.removed)
        self.assertIn("failed (1)", output.getvalue())
        self.assertIn("Freed in this run:", output.getvalue())

    def test_apply_json_reports_the_remaining_size_after_partial_removal(self) -> None:
        home = Path("/Users/example")
        removed, remaining = home / "removed", home / "locked"

        class PartiallyLockedFileSystem(FakeFileSystem):
            def unlink(self, path: Path) -> None:
                if path == remaining:
                    raise OSError("locked")
                super().unlink(path)

        files = PartiallyLockedFileSystem(home, existing=(removed, remaining))
        process = FakeOutputRunner(f"4\t{remaining}\n")
        category = Category(
            "app-caches", localized("Caches"), localized("Regenerable"), 8192,
            paths=(SizedPath(removed, 4096), SizedPath(remaining, 4096)),
        )
        report = report_from_payload(json.loads((FIXTURES / "scan-report.json").read_text()))
        operations = operations_for_report(
            report,
            files.free_bytes,
            lambda selected, language: runner.clean_category(selected, language, files),
            lambda selected: measurements.measure_selected_bytes(selected, files, process),
        )
        output = io.StringIO()
        with redirect_stdout(output):
            code = commands.run_apply(
                json.dumps([category_to_payload(category)]), "en", operations, json_output=True
            )
        self.assertEqual(0, code)

        result = json.loads(output.getvalue())
        self.assertEqual([removed], files.removed)
        self.assertEqual({remaining}, files.existing)
        self.assertEqual(8192, result["before_bytes"])
        self.assertEqual(4096, result["after_bytes"])
        self.assertIn("could not remove", result["log"])


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
        measured, unreadable = Path("/Users/example/a"), Path("/Users/example/locked")
        files = FakeFileSystem(Path("/Users/example"), existing=(measured, unreadable))
        fake = FakeOutputRunner(f"4\t{measured}\n")
        sizes = measurements.measure_bytes((measured, unreadable), files, fake)
        self.assertEqual(4096, sizes[measured])
        self.assertIsNone(sizes[unreadable])

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


class SelectedMeasurementTests(unittest.TestCase):
    def test_path_batch_preserves_order_and_counts_every_reference(self) -> None:
        home = Path("/Users/example")
        removed, remaining, unselected = home / "removed", home / "remaining", home / "other"
        files = FakeFileSystem(home, existing=(remaining, unselected))
        process = FakeOutputRunner(f"4\t{remaining}\n")
        category = Category(
            "app-caches", localized("Caches"), localized("Regenerable"), 8192,
            paths=(SizedPath(removed, 4096), SizedPath(remaining, 4096)),
        )
        self.assertEqual(4096, measurements.measure_selected_bytes((category,), files, process))
        repeated = replace(category, key="other-selected", paths=(SizedPath(remaining, 4096),))
        self.assertEqual(8192, measurements.measure_selected_bytes((category, repeated), files, process))
        batch = ("du", "-sk", "--", str(removed), str(remaining))
        self.assertEqual([batch, batch], process.commands)

    def test_unreadable_selected_path_makes_the_total_unavailable(self) -> None:
        home = Path("/Users/example")
        readable, unreadable = home / "readable", home / "unreadable"
        files = FakeFileSystem(home, existing=(readable, unreadable))
        process = FakeOutputRunner(f"4\t{readable}\n")
        selected = Category(
            "app-caches", localized("Caches"), localized("Regenerable"), 8192,
            paths=(SizedPath(readable, 4096), SizedPath(unreadable, 4096)),
        )
        self.assertIsNone(measurements.measure_selected_bytes((selected,), files, process))

    def test_empty_selection_and_pathless_category_run_no_commands(self) -> None:
        category = Category("app-caches", localized("Caches"), localized("Regenerable"), 0)
        process = FakeOutputRunner("")
        for selected in ((), (category,)):
            self.assertEqual(0, measurements.measure_selected_bytes(selected, process_runner=process))
        self.assertEqual([], process.commands)

    def test_docker_counts_only_images_and_build_cache_with_one_query(self) -> None:
        category = docker.build_docker_category({})
        process = FakeOutputRunner("Images|2MB\nBuild Cache|1MB\nLocal Volumes|7MB\nContainers|9MB\n")
        self.assertEqual(
            6_000_000, measurements.measure_selected_bytes((category, category), process_runner=process)
        )
        self.assertEqual([("docker", "system", "df", "--format", docker.DOCKER_DF_FORMAT)], process.commands)

    def test_unavailable_incomplete_or_invalid_docker_measurement(self) -> None:
        category = docker.build_docker_category({})
        for process in (
            FakeOutputRunner("", returncode=1),
            FakeOutputRunner("Images|2MB\n"),
            FakeOutputRunner("Images|2MB\nBuild Cache|invalid\n"),
        ):
            with self.subTest(stdout=process.stdout, returncode=process.returncode):
                self.assertIsNone(measurements.measure_selected_bytes((category,), process_runner=process))

    def test_unknown_commands_cannot_be_measured(self) -> None:
        category = docker.build_docker_category({})
        process = FakeOutputRunner("")
        for unknown in (replace(category, key="other"), replace(category, commands=(("other",),))):
            self.assertIsNone(measurements.measure_selected_bytes((unknown,), process_runner=process))
        self.assertEqual([], process.commands)

    def test_du_read_errors_make_the_total_unavailable(self) -> None:
        home = Path("/Users/example")
        path = home / "remaining"
        files = FakeFileSystem(home, existing=(path,))
        process = FakeOutputRunner("invalid size\n")
        selected = Category(
            "app-caches", localized("Caches"), localized("Regenerable"), 4096,
            paths=(SizedPath(path, 4096),),
        )
        self.assertIsNone(measurements.measure_selected_bytes((selected,), files, process))
        with patch.object(process, "run", side_effect=OSError("locked")):
            self.assertIsNone(measurements.measure_selected_bytes((selected,), files, process))


class FormattingTests(unittest.TestCase):
    def test_language_and_size_formatting(self) -> None:
        from ohmyheadroom_engine.cli.presentation import format_size

        self.assertEqual("pt", normalize_language("pt_BR.UTF-8"))
        self.assertEqual("1,2 KB", format_size(1234, "pt"))
        self.assertEqual("no access", format_size(None, "en"))


if __name__ == "__main__":
    unittest.main()
