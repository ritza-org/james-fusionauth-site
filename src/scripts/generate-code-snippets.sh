#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTRO_DIR="$(cd "$SCRIPT_DIR/../../astro" && pwd)"
cd "$ASTRO_DIR"

mkdir -p src/generated-code-snippets

for repo in src/code-example-repositories/*/; do
	output_dir="src/generated-code-snippets/$(basename "$repo")"
	mkdir -p "$output_dir"
	out=$(npx --yes bluehawk snip "$repo" \
		--output "$output_dir" \
		--plugin bluehawk-languages.js \
		--ignore 'node_modules' \
		--ignore '.gitignore' \
		--ignore '.DS_Store' \
		--ignore 'package*.json' \
		--ignore '*.lock' \
		--ignore 'repositoryUrl.txt' \
		--ignore 'tests' \
		--ignore 'LICENSE' \
		--ignore 'SECURITY.md' \
		2>&1)
	status=$?
	printf '%s\n' "$out" | grep -v 'parsed file' | grep -v 'found binary file'
	if [ $status -ne 0 ]; then
		echo "Error: bluehawk snip failed for $repo" >&2
		exit $status
	fi
done

find src/generated-code-snippets -type d -empty -delete
