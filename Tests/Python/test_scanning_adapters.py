"""Regression tests for scan, dependency, and Docker adapters."""

import unittest
from pathlib import Path

from adapter_fakes import FakeScanFileSystem, FakeScanProcessRunner
from headroom_engine.features.cleanup.catalog import ReviewRule, SafeRule
from headroom_engine.features.cleanup.scanning.dependencies import (
    build_dependency_categories,
    walk_dependency_dirs,
)
from headroom_engine.features.cleanup.scanning.docker import (
    build_docker_category,
    build_docker_volume_line,
    parse_docker_df,
    parse_docker_size,
)
from headroom_engine.features.cleanup.scanning.report import (
    ScanRuntime,
    build_report,
)
from headroom_engine.i18n import Localized


def text(value: str) -> Localized:
    """Create identical bilingual text for a focused adapter test."""
    return Localized(pt=value, en=value)


DependencyInputs = tuple[tuple[Path, ...], FakeScanFileSystem, FakeScanProcessRunner]


def dependency_inputs() -> DependencyInputs:
    """Build a fake project/worktree scan with deterministic dependency sizes."""
    home = Path("/runtime")
    roots = (home / "projects", home / "worktrees")
    filesystem = FakeScanFileSystem(home, walks=dependency_walks(roots))
    runner = FakeScanProcessRunner(
        "",
        {
            str(roots[0] / "node_modules"): 2048,
            str(roots[1] / "agent" / "node_modules"): 4096,
        },
    )
    return roots, filesystem, runner


def dependency_walks(
    roots: tuple[Path, ...],
) -> dict[Path, list[tuple[str, list[str], list[str]]]]:
    """Return project and worktree walk entries for dependency discovery."""
    return {
        roots[0]: [(str(roots[0]), ["node_modules", ".git"], [])],
        roots[1]: [
            (str(roots[1]), ["agent", ".git"], []),
            (str(roots[1] / "agent"), ["node_modules"], []),
        ],
    }


def report_runtime() -> ScanRuntime:
    """Build a fake scan runtime containing Docker and one safe rule."""
    home = Path("/runtime")
    cache = home / "cache"
    filesystem = FakeScanFileSystem(home, children={cache: [cache / "entry"]}, free=77)
    runner = FakeScanProcessRunner(
        "Images|1GB (10%)\nBuild Cache|2GB (20%)\nLocal Volumes|3GB (30%)",
        {str(cache / "entry"): 1024, str(home / "review"): 2048},
    )
    return ScanRuntime(
        filesystem=filesystem,
        process_runner=runner,
        safe_rules=(SafeRule("cache", text("Cache"), text("Cache"), (cache,)),),
        review_rules=(ReviewRule(text("Review"), text("Review"), home / "review"),),
        dependency_roots=(),
        dependency_dir_names=("node_modules",),
    )


class ScanningAdapterTests(unittest.TestCase):
    def test_dependency_categories_split_project_and_worktree_paths(self) -> None:
        roots, filesystem, runner = dependency_inputs()

        categories = build_dependency_categories(
            roots, ("node_modules",), filesystem, runner
        )

        self.assertEqual(
            ["deps-worktrees", "deps-projects"], [item.key for item in categories]
        )
        self.assertEqual(
            [roots[1] / "agent" / "node_modules"],
            [entry.path for entry in categories[0].paths],
        )
        self.assertEqual(
            [roots[0] / "node_modules"],
            [entry.path for entry in categories[1].paths],
        )
        self.assertEqual(4096, categories[0].size_bytes)
        self.assertEqual(2048, categories[1].size_bytes)

    def test_dependency_walk_prunes_git_and_dependency_directories(self) -> None:
        directories = ["node_modules", ".git", "src"]

        found = walk_dependency_dirs(
            iter([("/runtime", directories, [])]), ("node_modules",)
        )

        self.assertEqual([Path("/runtime/node_modules")], found)
        self.assertEqual(["src"], directories)

    def test_docker_category_keeps_volumes_in_review_only(self) -> None:
        reclaimable = parse_docker_df(
            "Images|1GB (10%)\nBuild Cache|2GB (20%)\nLocal Volumes|3GB (30%)"
        )
        category = build_docker_category(reclaimable)
        review = build_docker_volume_line(reclaimable)

        self.assertEqual(3_000_000_000, category.size_bytes)
        self.assertEqual(3_000_000_000, review.size_bytes)
        self.assertEqual(("docker", "image", "prune", "-a", "-f"), category.commands[0])
        self.assertFalse(any("volume" in command for command in category.commands))

    def test_docker_size_error_names_value_and_shape(self) -> None:
        with self.assertRaisesRegex(ValueError, "bad-size.*2.458GB"):
            parse_docker_size("bad-size")

    def test_build_report_orders_rule_docker_and_dependencies(self) -> None:
        runtime = report_runtime()

        report = build_report(runtime=runtime)

        self.assertEqual(
            ["cache", "docker-prune", "deps-worktrees", "deps-projects"],
            [item.key for item in report.safe],
        )
        self.assertEqual(
            ["Review", "Docker: volumes sem uso"],
            [item.label.pt for item in report.review],
        )
        self.assertEqual(77, report.free_bytes)


if __name__ == "__main__":
    unittest.main()
