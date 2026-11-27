#!/bin/sh
set -eu

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$repo_dir/.build/checks"
binary="$check_dir/OhMyHeadroomChecks"
mkdir -p "$check_dir"

swiftc -parse-as-library \
  "$repo_dir"/Sources/OhMyHeadroom/Features/Cleanup/Contracts/*.swift \
  "$repo_dir"/Sources/OhMyHeadroom/Features/Cleanup/Engine/*.swift \
  "$repo_dir"/Sources/OhMyHeadroom/Features/Cleanup/Formatting/*.swift \
  "$repo_dir"/Sources/OhMyHeadroom/Features/Cleanup/CleanupGateway.swift \
  "$repo_dir"/Sources/OhMyHeadroom/Features/Cleanup/CategorySelection.swift \
  "$repo_dir"/Sources/OhMyHeadroom/Features/Cleanup/CleanupModel.swift \
  "$repo_dir"/Tests/OhMyHeadroomTests/*.swift \
  -o "$binary"

cd "$repo_dir"
"$binary"
