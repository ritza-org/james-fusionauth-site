#!/usr/bin/env bash

# Publishes code examples from local directories to external repositories.
# Loops through every directory in astro/src/code-example-repositories/, strips Bluehawk annotations, and mirrors the content to each remote repository and branch specified in repositoryUrl.txt.
# repositoryUrl.txt format: one entry per line, "<url> <branch>" e.g. "github.com/FusionAuth/fusionauth-quickstart-javascript-nextjs-web main"

# Arguments:
#   $1 — The GitHub access token for pushing to external repositories.
#   $2 — The source commit SHA of the documentation repository to include in the commit message of the code example repository.

set -euo pipefail # crash on any error

GITHUB_TOKEN="$1"
DOCUMENTATION_COMMIT_HASH="$2"


for LOCAL_REPOSITORY_PATH in astro/src/code-example-repositories/*/; do

		REPOSITORY_NAME=$(basename "$LOCAL_REPOSITORY_PATH")
		URL_FILE="${LOCAL_REPOSITORY_PATH}repositoryUrl.txt"

		if [ ! -f "$URL_FILE" ]; then
			echo "Error: $REPOSITORY_NAME has no repositoryUrl.txt" >&2
			exit 1
		fi

		echo "Publishing $REPOSITORY_NAME"

		# Process local files with Bluehawk to strip annotations but not generate snippets (once per repo)
		ABS_REPOSITORY_PATH="$(pwd)/$LOCAL_REPOSITORY_PATH"
		cd astro
		LOCAL_CLEANED_REPOSITORY_PATH=$(mktemp -d /tmp/bluehawk-processed.XXXXXX)
		npx bluehawk copy --state published \
			-i "repositoryUrl.txt" \
			-i "tests" \
			--output "$LOCAL_CLEANED_REPOSITORY_PATH" \
			"$ABS_REPOSITORY_PATH"
		cd "$OLDPWD"

		# Push to each remote URL + branch listed in repositoryUrl.txt
		while IFS=' ' read -r PARTIAL_REMOTE_URL BRANCH; do
			[ -z "$PARTIAL_REMOTE_URL" ] && continue
			REMOTE_URL="https://x-access-token:${GITHUB_TOKEN}@${PARTIAL_REMOTE_URL}"

			echo "  -> $PARTIAL_REMOTE_URL ($BRANCH)"

			# Clone the remote repository
			LOCAL_CLONED_REPOSITORY_PATH=$(mktemp -d /tmp/code-example-repository.XXXXXX)
			git clone "$REMOTE_URL" "$LOCAL_CLONED_REPOSITORY_PATH"
			cd "$LOCAL_CLONED_REPOSITORY_PATH"

			git config user.email "actions@github.com"
			git config user.name "GitHub Actions"

			# Checkout target branch, crash if it doesn't exist
			git checkout "$BRANCH" || exit 1

			# Replace the entire working tree with the processed files to mirror exactly
			git rm -rf .
			git clean -fdxq
			cp -r "$LOCAL_CLEANED_REPOSITORY_PATH/." .

			# Commit if there are changes
			git add -A
			if ! git diff --cached --quiet; then
				git commit -m "chore: update from fusionauth-site ${DOCUMENTATION_COMMIT_HASH}"
				git push origin "$BRANCH"
			fi

			# Remove cloned repo
			cd "$OLDPWD"
			rm -rf "$LOCAL_CLONED_REPOSITORY_PATH"
		done < "$URL_FILE"

		# Remove Bluehawk-processed copy
		rm -rf "$LOCAL_CLEANED_REPOSITORY_PATH"
done
