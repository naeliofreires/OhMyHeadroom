#!/bin/sh
set -eu

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$repo_dir/.build/checks"
binary="$check_dir/PoliceScanChecks"
mkdir -p "$check_dir"

swiftc -parse-as-library \
  "$repo_dir"/Sources/PoliceScan/Features/Cleanup/Contracts/*.swift \
  "$repo_dir"/Sources/PoliceScan/Features/Cleanup/Engine/*.swift \
  "$repo_dir"/Sources/PoliceScan/Features/Cleanup/Formatting/*.swift \
  "$repo_dir"/Sources/PoliceScan/Features/Cleanup/CleanupGateway.swift \
  "$repo_dir"/Sources/PoliceScan/Features/Cleanup/CleanupModel.swift \
  "$repo_dir"/Tests/PoliceScanTests/*.swift \
  -o "$binary"

cd "$repo_dir"
"$binary"
