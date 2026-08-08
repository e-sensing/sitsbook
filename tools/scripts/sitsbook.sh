#!/usr/bin/env bash
set -euo pipefail

# Run the sitsbook data-generation step using the local booksetup package.
# Each run gets a timestamped output script and log in tempdir/.
# A YAML registry tracks completed chunks, so only new/failed chunks re-run.

export SITS_DOCUMENTATION_MODE="TRUE"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mkdir -p tempdir

Rscript -e "
  pkgload::load_all('tools/booksetup', quiet = TRUE)
  booksetup::generate_book_data(
    book_dir    = '$REPO_ROOT',
    python_sync = TRUE
  )
"
