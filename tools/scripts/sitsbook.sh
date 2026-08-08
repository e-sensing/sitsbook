#!/usr/bin/env bash
set -euo pipefail

# Run the sitsbook data-generation step using the local booksetup package.
# Each run gets a timestamped output script and log in tempdir/.
# A YAML registry tracks completed chunks, so only new/failed chunks re-run.

usage() {
  cat <<EOF
Usage: $(basename "$0") [-h|--help] [chapter ...]

Run booksetup::generate_book_data() to (re)generate the book's temp data
(rasters, cubes, plots, etc.) under ~/sitsbook/tempdir/, using the local
booksetup package (tools/booksetup).

Arguments:
  chapter ...   Optional chapter name(s) (without .qmd, as they appear in
                _quarto.yml) to limit the run to just those chapters. If
                omitted, the whole book is generated, excluding
                "intro_examples".

Options:
  -h, --help    Show this help message.

Examples:
  $(basename "$0")                            # whole book (except intro_examples)
  $(basename "$0") dc_ardcollections          # just one chapter
  $(basename "$0") dc_ardcollections dc_merge # a few chapters
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

export SITS_DOCUMENTATION_MODE="TRUE"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mkdir -p tempdir

if [[ $# -gt 0 ]]; then
  # Accept chapter names with or without a trailing ".qmd".
  CHAPTERS=("${@%.qmd}")
  CHAPTERS_R="c($(printf "'%s'," "${CHAPTERS[@]}" | sed 's/,$//'))"
else
  CHAPTERS_R="NULL"
fi

Rscript -e "
  pkgload::load_all('tools/booksetup', quiet = TRUE)
  booksetup::generate_book_data(
    book_dir    = '$REPO_ROOT',
    chapters    = $CHAPTERS_R,
    exclude     = if (is.null($CHAPTERS_R)) 'intro_examples' else NULL,
    python_sync = TRUE
  )
"
