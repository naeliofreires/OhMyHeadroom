#!/bin/sh
set -eu

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$repo_dir/.build/checks"
binary="$check_dir/HeadroomChecks"
mkdir -p "$check_dir"

swiftc -parse-as-library \
  "$repo_dir"/Sources/Headroom/Features/Cleanup/Contracts/*.swift \
  "$repo_dir"/Sources/Headroom/Features/Cleanup/Engine/*.swift \
  "$repo_dir"/Sources/Headroom/Features/Cleanup/Formatting/*.swift \
  "$repo_dir"/Sources/Headroom/Features/Cleanup/CleanupGateway.swift \
  "$repo_dir"/Sources/Headroom/Features/Cleanup/CleanupModel.swift \
  "$repo_dir"/Tests/HeadroomTests/*.swift \
  -o "$binary"

cd "$repo_dir"
"$binary"
