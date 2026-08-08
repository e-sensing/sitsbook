#!/usr/bin/env bash
set -euo pipefail

# Print a triage report over the booksetup chunk registry: failed chunks,
# slow chunks (optionally filtered by eval:true/false), and chunks that
# produced saved plot images. Uses the local booksetup package
# (tools/booksetup), same as tools/scripts/sitsbook.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REGISTRY="${HOME}/sitsbook/tempdir/.booksetup_registry.yaml"
THRESHOLD=10
TOP=20
EVAL_ONLY="true"
SECTION="all"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Print a triage report over a booksetup chunk registry (.booksetup_registry.yaml),
built from the R functions list_failed_chunks(), list_slow_chunks(), and
list_chunks_with_images() in tools/booksetup.

Options:
  -r, --registry PATH      Path to the .booksetup_registry.yaml file.
                            (default: ${REGISTRY})

  -t, --threshold SECONDS  Minimum elapsed time (seconds) a chunk must have
                            to appear in the "slow chunks" report.
                            (default: ${THRESHOLD})

  -e, --eval-only MODE     Which chunks to include in the "slow chunks"
                            report, by their eval: setting:
                              true  - only eval:true chunks (chunks Quarto
                                      actually re-runs on every render; this
                                      is the usual case for intervention)
                              false - only eval:false chunks
                              all   - no filtering on eval (also includes
                                      legacy entries with eval unknown/NA)
                            (default: ${EVAL_ONLY})

  -n, --top N               Max rows to print per report section.
                            (default: ${TOP})

  -s, --section SECTION    Which report section(s) to print, comma-separated.
                            One or more of:
                              failed - chunks with status == "error"
                              slow   - slow chunks (see --threshold/--eval-only)
                              images - chunks that produced saved plot images
                              all    - all of the above (default)

  -h, --help               Show this help message.

Examples:
  # Default: eval:true chunks slower than 10s, plus failures and images
  $(basename "$0")

  # Only the failed-chunks report
  $(basename "$0") --section failed

  # Slow chunks (any eval, including legacy entries), threshold 30s, top 15
  $(basename "$0") --section slow --eval-only all --threshold 30 --top 15

  # Use a different registry file
  $(basename "$0") --registry /path/to/.booksetup_registry.yaml
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--registry)
      REGISTRY="$2"; shift 2 ;;
    -t|--threshold)
      THRESHOLD="$2"; shift 2 ;;
    -e|--eval-only)
      EVAL_ONLY="$2"; shift 2 ;;
    -n|--top)
      TOP="$2"; shift 2 ;;
    -s|--section)
      SECTION="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

case "$EVAL_ONLY" in
  true|false|all) ;;
  *)
    echo "Invalid --eval-only value: $EVAL_ONLY (must be true, false, or all)" >&2
    exit 1 ;;
esac

if [[ ! -f "$REGISTRY" ]]; then
  echo "Registry file not found: $REGISTRY" >&2
  exit 1
fi

Rscript -e "
  pkgload::load_all('$REPO_ROOT/tools/booksetup', quiet = TRUE)

  registry  <- registry_read('$REGISTRY')
  threshold <- $THRESHOLD
  top_n     <- $TOP
  eval_only <- switch('$EVAL_ONLY', true = TRUE, false = FALSE, all = NULL)
  sections  <- strsplit('$SECTION', ',', fixed = TRUE)[[1L]]
  show_all  <- 'all' %in% sections

  cat('Registry: $REGISTRY\n')
  cat('Total chunks:', length(registry), '\n')

  if (show_all || 'failed' %in% sections) {
    cat('\n== Failed chunks (status == \"error\") ==\n')
    failed <- list_failed_chunks(registry)
    if (nrow(failed) == 0L) {
      cat('(none)\n')
    } else {
      print(utils::head(failed, top_n))
    }
  }

  if (show_all || 'slow' %in% sections) {
    eval_desc <- if (is.null(eval_only)) 'any eval' else paste0('eval:', tolower(eval_only))
    cat('\n== Slow chunks (', eval_desc, ', elapsed >', threshold, 's) ==\n')
    slow <- list_slow_chunks(registry, eval_only = eval_only, n = Inf)
    slow <- slow[slow\$elapsed > threshold, , drop = FALSE]
    if (nrow(slow) == 0L) {
      cat('(none)\n')
    } else {
      print(utils::head(slow, top_n))
    }
  }

  if (show_all || 'images' %in% sections) {
    cat('\n== Chunks with saved plot images ==\n')
    imgs <- list_chunks_with_images(registry)
    if (nrow(imgs) == 0L) {
      cat('(none)\n')
    } else {
      print(utils::head(imgs, top_n))
    }
  }
"
