# booksetup

A local R package that powers the two-phase build of the
[sitsbook](https://github.com/e-sensing/sitsbook) Quarto project. It
extracts every R code chunk from the `.qmd` chapters (including those
marked `eval: false`), executes them in a standalone script, caches
results in a YAML registry, and saves plot images as PNGs -- so that
Quarto rendering is fast, reproducible, and does not require live access
to cloud data services.

**booksetup runs _before_ Quarto, not inside it.** It is a standalone
pre-processing step: you run it once (via `sitsbook.sh` or
`generate_book_data()`) to populate `etc/` and `tempdir/` with
pre-computed data, and then `quarto render` builds the book using that
data. The two tools never interact at runtime -- no `.qmd` chapter
imports or calls booksetup. Chapters use only standard Quarto/knitr
constructs (`eval`, `echo`, `readRDS`, `knitr::include_graphics`).

## Table of contents

1. [The two-phase build](#1-the-two-phase-build)
2. [Quick start (proof-readers)](#2-quick-start-proof-readers)
3. [Writing and editing chapters](#3-writing-and-editing-chapters)
4. [Diagnosing and triaging runs](#4-diagnosing-and-triaging-runs)
5. [R API reference](#5-r-api-reference)
6. [File layout](#6-file-layout)
7. [Internals (for booksetup developers)](#7-internals-for-booksetup-developers)

---

## 1. The two-phase build

Building the book happens in two distinct phases:

### Phase 1 -- Data generation (`booksetup`)

`generate_book_data()` (or the shell wrapper `tools/scripts/sitsbook.sh`)
does the following:

1. Reads `_quarto.yml` to discover all chapter `.qmd` files in book
   order.
2. Extracts **every** R chunk from each chapter, including those marked
   `#| eval: false`.
3. Assembles them into a single timestamped R script
   (`tempdir/generate_book_data_<timestamp>.R`).
4. Sources that script, executing each chunk through
   `evaluate::evaluate()`.
5. Records each chunk's status, elapsed time, code hash, and saved
   images in a YAML registry
   (`~/sitsbook/tempdir/.booksetup_registry.yaml`).
6. Saves any plots produced by chunks as PNG files under
   `~/sitsbook/tempdir/generated_images/<chapter>/`.
7. Syncs the R output directory to the Python output directory via
   `rsync`.

Chapters run in **isolated environments** -- variables defined in one
chapter never leak into the next. Package-install lines
(`install.packages`, `devtools::install_github`, etc.) are automatically
stripped from the generated script.

On subsequent runs, `eval: false` chunks whose code hash has not changed
and whose previous status is `"ok"` are **skipped**. `eval: true` chunks
always re-run. Chunks that previously errored always re-run regardless
of their `eval` setting.

### Phase 2 -- Quarto rendering

A standard `quarto render` builds the HTML book. During this phase:

- **`eval: false` chunks** are displayed to the reader but **not
  executed**.
- **Hidden bridge chunks** (`echo: false`) immediately follow them and
  load the pre-computed result via `readRDS("./etc/<file>.rds")`, making
  the variable available for subsequent chunks.
- **`eval: true` chunks** run normally, using variables populated by the
  bridge chunks.

This is the key pattern that makes the two phases work together:

```r
# Shown to the reader, NOT executed by Quarto:
```{r}
#| eval: false
lem_cube <- sits_cube_copy(
    cube = bdc_cube, roi = roi_lem, output_dir = tempdir_r
)
```

# Hidden from the reader, IS executed by Quarto:
```{r}
#| echo: false
lem_cube <- readRDS("./etc/lem_cube.rds")
```
```

---

## 2. Quick start (proof-readers)

### Prerequisites

- R (>= 4.1) with `sits`, `sitsdata`, and their system dependencies
  (GDAL, PROJ, GEOS) installed.
- The `pkgload` package (`install.packages("pkgload")`).
- Quarto CLI.

### Generate data for one or more chapters

```bash
# One chapter:
tools/scripts/sitsbook.sh dc_ardcollections

# Several chapters:
tools/scripts/sitsbook.sh dc_ardcollections dc_merge ts_basics

# The whole book (excludes intro_examples by default):
tools/scripts/sitsbook.sh
```

### Render the book

```bash
quarto render
```

### Check for failures

```bash
tools/scripts/chunk_triage.sh --section failed
```

Or from R:

```r
pkgload::load_all("tools/booksetup")
reg <- registry_read(registry_path())
list_failed_chunks(reg)
```

---

## 3. Writing and editing chapters

### 3.1 Chunk conventions

Every R chunk in a `.qmd` file falls into one of these roles:

| Role | `eval` | `echo` | Purpose |
|---|---|---|---|
| Setup | `true` | `true` | Load libraries, create `tempdir_r` |
| Expensive operation | `false` | `true` | Show code to reader; runs only in Phase 1 |
| Bridge (hidden loader) | `false` | `false` | Load `.rds` result for Quarto; runs only in Phase 2 |
| Display / analysis | `true` | `true` | Uses variables from bridge chunks |
| Static image | `false` | `false` | `knitr::include_graphics("./images/...")` |

**When to mark a chunk `eval: false`:**

- It accesses cloud services (AWS, Microsoft Planetary Computer, etc.)
- It trains a machine-learning model or runs a classification
- It downloads or copies large raster data
- It takes more than a few seconds to run

**The bridge pattern step-by-step:**

1. Write the `eval: false` chunk with the expensive code.
2. Immediately below it, add a hidden chunk that loads the pre-computed
   result:
   ```r
   ```{r}
   #| echo: false
   my_result <- readRDS("./etc/my_result.rds")
   ```
   ```
3. Make sure the data-generation script (`sitsbook.sh`) saves the result
   to `./etc/` (via an explicit `saveRDS()` call within the `eval: false`
   chunk or from booksetup's execution of that chunk).

**Label your chunks.** Use `#| label: fig-my-plot` to give chunks
meaningful names. Labels appear in the registry, in image filenames
(`chapter_03-fig-my-plot_p1.png`), and in diagnostic reports.

### 3.1.1 Snapshot/restore vs. the `.qmd` bridge chunk -- two different jobs

booksetup has an internal chunk **snapshot/restore** mechanism (see
[Internals](#7-internals-for-booksetup-developers)) that keeps
`generate_book_data()` itself robust to re-runs: when an `eval: false`
chunk is skipped because its hash is unchanged, booksetup transparently
restores the variables it previously defined into the *data-generation
session*, so that later `eval: true` chunks in the same chapter don't
fail with "object not found" the second time you run `sitsbook.sh`.

This is **not** a substitute for the `.qmd` bridge chunk described
above. Per the two-phase build (section 1), booksetup and Quarto never
interact at runtime -- a real `quarto render` starts a fresh knitr
session per chapter and has no access to booksetup's internal
`.snapshots/` cache. The chapter still needs its own small, explicit
bridge chunk (`readRDS("./etc/...")`) so that Quarto rendering works
independently of booksetup. **Never call any `booksetup::` function
from a `.qmd` chapter** -- that would break the documented separation
between the two tools.

In short:

| Mechanism | Fixes | Scope |
|---|---|---|
| Internal snapshot/restore | `generate_book_data()` re-runs without "object not found" errors on skipped `eval:false` chunks | booksetup's own execution only |
| `.qmd` bridge chunk (`readRDS("./etc/...")`) | Quarto rendering without re-running expensive/live code | Every chapter, always required |

### 3.1.2 Migration playbook: retiring a fragile bridge chunk

Some chapters (historically) grew ad hoc bridge logic instead of the
plain pattern above -- e.g. dual save-or-load chunks keyed on
`exists()`, or hardcoded absolute paths that bypass `./etc/`. Retire
these one chapter at a time:

1. **Identify** the `eval: false` "defining" chunk and the chunk(s)
   that display/consume its results.
2. **Confirm** the defining chunk assigns its result(s) to named
   variables (not just prints them) -- required for both the
   `saveRDS()` call and (during `generate_book_data()` re-runs) for
   booksetup's snapshot mechanism to pick them up.
3. **Add** an explicit `saveRDS(x, "./etc/x.rds")` call at the end of
   the defining chunk for each object the bridge needs.
4. **Replace** any dual save-or-load / `exists()` / `tempdir`-based
   logic with a plain, unconditional bridge chunk:
   ```r
   ```{r}
   #| echo: false
   x <- readRDS("./etc/x.rds")
   ```
   ```
5. For a Python tab that needs the same object, read directly from the
   same `./etc/x.rds` file with `read_rds("./etc/x.rds")` -- no
   R-populated `tempdir/Python` mirror is needed for this purpose.
6. Run `generate_book_data(chapters = "<chapter>")` twice locally to
   confirm the chapter's chunks all succeed on both a fresh run and a
   skip-heavy re-run, then (if feasible) do a `quarto render` of the
   chapter to confirm the visible output is unchanged.
7. Commit the chapter's `.rds` file(s) under `etc/` if they don't
   already exist there.

**Migration candidates identified so far** (each needs individual
inspection before editing -- not every `.rds` read in these chapters is
a fragile bridge; some may be legitimate one-way caches with no
in-session counterpart):

- `cl_ensembleprediction.qmd` -- 5 sites read from the *hardcoded
  absolute path* `~/sitsbook/etc/<name>.rds` instead of the relative
  `./etc/<name>.rds` used everywhere else, and the corresponding
  `eval: false` chunks don't `saveRDS()` the displayed object at all
  (the committed `.rds` was produced by hand at some point and has no
  automatic link back to the code that should regenerate it). This is
  the top candidate for the next migration pass.
- Other chapters with `.rds`-based bridges worth auditing:
  `intro_quicktour.qmd`, `ts_basics.qmd`, `val_map.qmd`,
  `emb_build.qmd`, `dc_regularize.qmd`, `cl_tuning.qmd`,
  `cl_rasterclassification.qmd`, `ts_som.qmd`, `ts_balance.qmd`,
  `intro_examples.qmd` -- most already follow the plain
  `readRDS("./etc/...")` pattern and don't need changes; each should
  still be spot-checked individually.
- `etc/` contains committed `.rds` files not referenced by literal path
  from any current `.qmd` (found via `git ls-files etc/*.rds` cross
  referenced with chapter reads). Before deleting any of them, confirm
  with `git log --follow` that they're genuinely unused rather than
  read via a non-literal/constructed path.

### 3.2 Re-generating data after edits

**Automatic re-run on code change:** if you edit an `eval: false`
chunk, its MD5 hash changes and booksetup will re-run it on the next
`sitsbook.sh` invocation. No manual intervention needed.

**Force a specific chunk to re-run** (even if its hash hasn't changed):

```r
pkgload::load_all("tools/booksetup")
registry_clear("dc_merge", chunk = 7)
```

**Force an entire chapter to re-run:**

```r
registry_clear("dc_merge")
```

**Force multiple chapters:**

```r
registry_clear(c("dc_merge", "dc_regularize"))
```

Then run `sitsbook.sh` to execute the cleared chunks.

### 3.3 Working with generated images

Chunks that produce plots during Phase 1 have their output saved
automatically under:

```
~/sitsbook/tempdir/generated_images/<chapter>/
```

File naming convention:

```
<chapter>_<chunk_index>-<label>_p<plot_number>.png
```

Examples:

- `ts_basics_06-fig-ts-cerrado_p1.png` -- chunk 6, label
  `fig-ts-cerrado`, first plot.
- `dc_regularize_04-chunk_4_p1.png` -- chunk 4, no label (falls back to
  `chunk_4`).

To use a generated image in the book as a static reference, copy it to
`./images/` and display it via:

```r
```{r}
#| echo: false
knitr::include_graphics("./images/my_plot.png")
```
```

Default image settings are 2000 x 1500 px at 150 DPI. These can be
overridden via `build_data_script()` parameters `image_width`,
`image_height`, `image_res`.

### 3.4 Python code

- `booksetup` extracts **only R chunks**. Python chunks
  (`` ```{python} ``) are completely ignored during data generation.
- After Phase 1 completes, R-generated data is synced to the Python temp
  directory:
  ```
  rsync -a ~/sitsbook/tempdir/R/ ~/sitsbook/tempdir/Python/
  ```
- Python chunks in `.qmd` files can therefore read shared data from
  `~/sitsbook/tempdir/Python/<chapter>/`.

### 3.5 Running a single chapter

```bash
tools/scripts/sitsbook.sh intro_quicktour
```

Accepts chapter names with or without `.qmd`. Multiple names are
space-separated.

---

## 4. Diagnosing and triaging runs

### 4.1 Shell-based triage

`tools/scripts/chunk_triage.sh` prints a combined report from the
registry:

```bash
# Full report (failures + slow eval:true > 10s + images):
tools/scripts/chunk_triage.sh

# Only failures:
tools/scripts/chunk_triage.sh --section failed

# Slow eval:false chunks above 30s, top 15:
tools/scripts/chunk_triage.sh --section slow --eval-only false --threshold 30 --top 15

# Slow chunks regardless of eval setting:
tools/scripts/chunk_triage.sh --section slow --eval-only all --threshold 60

# Only chunks that produced images:
tools/scripts/chunk_triage.sh --section images
```

| Option | Default | Description |
|---|---|---|
| `-r, --registry` | `~/sitsbook/tempdir/.booksetup_registry.yaml` | Registry file path |
| `-t, --threshold` | `10` | Min elapsed seconds for the "slow" report |
| `-e, --eval-only` | `true` | Filter: `true`, `false`, or `all` |
| `-n, --top` | `20` | Max rows per report section |
| `-s, --section` | `all` | `failed`, `slow`, `images`, or comma-separated |

### 4.2 Registry queries (R console)

```r
pkgload::load_all("tools/booksetup")
reg <- registry_read(registry_path())

# Failed chunks (most recent first):
list_failed_chunks(reg)

# Slowest eval:true chunks (candidates for conversion to eval:false):
list_slow_chunks(reg, eval_only = TRUE)

# Slowest eval:false chunks:
list_slow_chunks(reg, eval_only = FALSE, n = 10)

# All completed chunks regardless of eval:
list_slow_chunks(reg, eval_only = NULL)

# Top 10 slowest successful chunks:
chunk_report(reg, n = 10)

# Chunks that produced plot images:
list_chunks_with_images(reg)

# Full data frame for custom filtering:
df <- registry_to_df(reg)
df[df$eval == TRUE & df$elapsed > 30, ]
```

### 4.3 Event logs

Every `sitsbook.sh` run produces a structured `.log` file alongside the
generated script in `tempdir/`. The log is a valid YAML document (one
flow-style mapping per event line) and can be parsed programmatically:

```r
events <- read_event_log("tempdir/generate_book_data_20260808_012459.log")
df <- event_log_to_df(events)
```

Event types logged: `run_start`, `chapter_start`, `chapter_end`,
`chapter_error`, `chunk_ok`, `chunk_skip`, `chunk_warning`,
`chunk_error`, `run_end`.

Each event includes a timestamp, and chapter/chunk events include
elapsed time. `chapter_end` events also log an ETA for the remaining
chapters based on average elapsed time.

### 4.4 CSV summary

A `chunk_summary.csv` snapshot of the full registry is written
automatically at the end of every run, next to the registry file. You
can also generate it manually:

```r
write_chunk_summary(reg, "my_summary.csv")
```

### 4.5 Snapshot diagnostics

A `snapshot_summary.csv` is also written automatically at the end of
every run, next to the registry file, reporting the health of the
internal chunk snapshot cache (`.snapshots/`, see section 3.1.1 and
7). One row per chunk:

| Column | Meaning |
|---|---|
| `chapter`, `chunk`, `key` | Chunk identity (`key` is `"chapter:chunk"`). |
| `n_vars` | Number of variables captured in the snapshot. |
| `size_bytes` | Total size on disk of the snapshotted `.rds` files. |
| `status` | `"ok"`, `"missing"`, `"empty"`, or `"not_applicable"` (see below). |

`status` values:

- **`not_applicable`** -- the chunk is `eval: true`, or its last run
  errored. Snapshotting only ever applies to successfully-completed
  `eval: false` chunks.
- **`missing`** -- an `eval: false` chunk completed `"ok"` but has no
  snapshot directory at all. This is *expected* for chunks that define
  no new variables (e.g. a chunk that only writes files to disk via
  `sits_regularize(..., output_dir = ...)`), so treat it as a signal to
  investigate rather than a hard error: check whether a downstream
  chunk actually needs a variable from this one.
- **`empty`** -- the snapshot directory exists but has no `.rds` files
  in it (every candidate variable exceeded the size guard, see 7).
- **`ok`** -- at least one variable was snapshotted; `n_vars` and
  `size_bytes` are populated.

Query it directly from R:

```r
pkgload::load_all("tools/booksetup")
reg <- registry_read(registry_path())
info <- snapshot_info(reg, file.path(dirname(registry_path()), ".snapshots"))

# Chunks whose snapshot is missing when it might not be expected to be:
info[info$status %in% c("missing", "empty"), ]

# Total snapshot disk usage:
sum(info$size_bytes)
```

---

## 5. R API reference

### Build and run

| Function | Description |
|---|---|
| `generate_book_data(book_dir, ...)` | Run every chapter's R chunks directly (extract, evaluate, skip/cache via registry, snapshot/restore, capture plots). |
| `build_data_script(book_dir, output, chapters, exclude, registry, python_sync, image_dir, image_width, image_height, image_res)` | Write a thin `.R` script that calls `generate_book_data()` with the given arguments, for workflows that prefer an explicit script file. |
| `chapter_files(book_dir)` | List `.qmd` chapter files in book order from `_quarto.yml`. |
| `extract_r_chunks(qmd)` | Extract all R chunks from a `.qmd` file (including `eval: false`). |

### Registry management

| Function | Description |
|---|---|
| `registry_path(tempdir)` | Default registry path (`~/sitsbook/tempdir/.booksetup_registry.yaml`). |
| `registry_read(path)` | Read the YAML registry (empty list if missing). |
| `registry_write(path, registry)` | Write the registry back to YAML. |
| `registry_key(chapter, index)` | Build a `"chapter:index"` key. |
| `registry_clear(chapter, chunk, registry)` | Remove entries to force re-execution. |
| `registry_to_df(registry)` | Convert registry to a 12-column data frame. |
| `chunk_hash(code)` | Compute MD5 hash for a chunk's code lines. |

### Registry reports

| Function | Description |
|---|---|
| `chunk_report(registry, n)` | Top *n* slowest successful chunks. |
| `list_failed_chunks(registry)` | Chunks with `status == "error"`, most recent first. |
| `list_slow_chunks(registry, eval_only, n)` | Slowest chunks filtered by `eval` setting. |
| `list_chunks_with_images(registry)` | Chunks that produced saved plot images. |
| `chunk_summary_df(registry)` | Full data frame (alias for `registry_to_df`). |
| `write_chunk_summary(registry, path)` | Write full registry to CSV. |

### Snapshot / restore

| Function | Description |
|---|---|
| `snapshot_chunk_env(key, env, pre_vars, snapshot_dir, max_bytes)` | Save an `eval: false` chunk's newly-defined variables as `.rds` files (internal; called by `run_chunk()`). |
| `restore_chunk_env(key, env, snapshot_dir)` | Restore a chunk's snapshotted variables into an environment (internal; called by `run_chunk()` on skip). |
| `snapshot_info(registry, snapshot_dir)` | Per-chunk snapshot diagnostics: variable count, size, and `"ok"`/`"missing"`/`"empty"`/`"not_applicable"` status. |
| `write_snapshot_summary(registry, snapshot_dir, path)` | Write `snapshot_info()` output to CSV. |

### Event log

| Function | Description |
|---|---|
| `read_event_log(path)` | Parse a `.log` file into a list of event records. |
| `event_log_to_df(events)` | Flatten event records into a data frame. |

---

## 6. File layout

```
sitsbook/                            # book project root
  _quarto.yml                        # book structure (parts and chapters)
  *.qmd                              # chapter source files
  etc/                               # pre-computed .rds objects (committed)
  images/                            # static figures (committed)
  tools/
    booksetup/                       # this R package
      R/                             # package source, including the
                                      # runtime engine (R/runtime.R) and
                                      # snapshot/restore (R/snapshot.R)
      inst/extdata/                  # test fixtures
      man/                           # roxygen2 documentation
      tests/                         # testthat test suite
      .github/workflows/             # CI (R-CMD-check on 5 OS/R-version combos)
    scripts/
      sitsbook.sh                    # shell entry point for data generation
      chunk_triage.sh                # shell entry point for registry diagnostics

~/sitsbook/tempdir/                  # generated data (NOT committed, in .gitignore)
  .booksetup_registry.yaml           # chunk completion registry
  .snapshots/                        # per-chunk variable snapshots (internal)
    <chapter>:<chunk>/
      <variable>.rds
  chunk_summary.csv                  # CSV snapshot of registry (auto-generated)
  snapshot_summary.csv               # CSV snapshot of snapshot diagnostics (auto-generated)
  generate_book_data_<timestamp>.log # structured YAML event log
  generated_images/                  # plot images captured during data generation
    <chapter>/
      <chapter>_<index>-<label>_p<n>.png
  R/                                 # R-generated chapter data
    <chapter>/                       # rasters, cubes, etc.
  Python/                            # rsync mirror of R/ for Python chunks
    <chapter>/
```

### Registry entry structure

Each entry in `.booksetup_registry.yaml` is keyed by `"chapter:index"`:

```yaml
dc_regularize:6:
  status: ok
  hash: c5e3102a228e5f2ec79c79a40a5fd629
  elapsed: 4643.429
  lines: 131-157
  label: chunk_6
  eval: no
  images:
  - /home/user/sitsbook/tempdir/generated_images/dc_regularize/dc_regularize_06-chunk_6_p1.png
```

Fields: `status` (`ok` | `error`), `hash` (MD5 of code), `elapsed`
(seconds), `lines` (source location), `label`, `eval`, `images` (list
of saved PNG paths), `error` (message, only when `status: error`),
`timestamp` (only when `status: error`).

---

## 7. Internals (for booksetup developers)

### Execution model

`generate_book_data()` calls the runtime engine (`R/runtime.R`)
directly -- there is no intermediate generated-script-as-a-string step.
For each chapter (in `_quarto.yml` order): `extract_r_chunks()` pulls
every R chunk out of the `.qmd`, and `run_chapter()`/`run_chunk()` (from
`R/runtime.R`) evaluate them in a per-chapter environment, using a
`new_run_state()` object (an environment holding the registry, log
connection, image/snapshot settings, and error list) that is passed
explicitly rather than mutated via `<<-`. `pdf(file = NULL)` is set once
up front to prevent the default PDF device from interfering with plot
capture.

`build_data_script()` remains available for workflows that prefer an
explicit `.R` file: it writes a short script whose only job is to call
`booksetup::generate_book_data()` with the given arguments -- it is a
thin wrapper, not a code generator.

### Snapshot / restore mechanism

`eval: false` chunks are only re-run when their code hash changes (see
skip logic below); otherwise they're skipped on every subsequent
`generate_book_data()` run. Without help, this would break any
`eval: true` chunk later in the same chapter that depends on a variable
the skipped chunk would have defined (a fresh R session has no memory
of it). `run_chunk()` (`R/runtime.R`) solves this with
`R/snapshot.R`:

- After an `eval: false` chunk **executes** (i.e. is not skipped) and
  succeeds, `snapshot_chunk_env()` diffs the chunk's environment
  against its pre-chunk variable list and saves each *new* variable as
  `<snapshot_dir>/<chapter>:<chunk>/<variable>.rds`. Objects larger
  than `state$snapshot_max_bytes` (default 50 MB) are skipped with a
  message rather than snapshotted.
- When an `eval: false` chunk is **skipped**, `restore_chunk_env()`
  loads every `.rds` file under its snapshot directory back into the
  chapter environment before returning, so downstream chunks see the
  same variables as if the chunk had actually run.
- `eval: true` chunks are never snapshotted (they always re-run, so
  there's nothing to restore).
- Snapshots are implicitly invalidated by the existing hash-based skip
  logic: if a defining chunk's code changes, its hash changes, it
  re-runs, and `snapshot_chunk_env()` overwrites the old snapshot.

This is purely an implementation detail of `generate_book_data()`'s own
re-run robustness -- it is invisible to, and independent of, the
`.qmd` bridge-chunk pattern used for actual Quarto rendering (see
3.1.1). Diagnostics for this cache are exposed via `snapshot_info()`
(section 4.5).

### run_chunk() skip logic

```
if eval == FALSE
  AND registry has an existing entry with status != "error"
  AND the code hash matches
  -> SKIP (log chunk_skip, return early)

Otherwise -> EXECUTE via evaluate::evaluate()
```

Key implications:

- `eval: true` chunks **always run**, even if already in the registry.
- `eval: false` chunks skip only when hash matches and status is ok.
- Chunks with `status: "error"` **always retry**, regardless of eval.
- If a chunk's label changes but its hash is unchanged, the registry
  label is updated without re-execution.

### Chunk execution

Each chunk is evaluated via `evaluate::evaluate()` with:

- `new_device = TRUE` -- captures plots in a fresh graphics device.
- `stop_on_error = 1L` -- stops on the first error within a chunk.
- `keep_warning = TRUE`, `keep_message = TRUE` -- preserves diagnostics.

After execution, `save_chunk_plots()` filters the results for
`"recordedplot"` objects (base graphics, ggplot2, tmap, etc.) and
replays each into a PNG file.

### Chapter isolation

Each chapter runs in its own `environment()` via the `env` parameter
passed to `run_chunk()`. Variables from one chapter are invisible to the
next. This is tested explicitly with the `isolation_book/` test fixture.

### Install-line stripping

`generate_book_data()` removes lines matching the following from each
chunk's code before evaluating it:

```
install.packages | ::install_github | ::install | BiocManager::install
```

This prevents accidental package installation during data generation.

### Structured logging

The `.log` file is a valid YAML sequence of flow-style mappings:

```yaml
- {event: "run_start", time: "2026-08-08T01:24:59.123", n_chapters: 5}
- {event: "chapter_start", time: "...", chapter: "dc_ardcollections", index: 1, total: 5}
- {event: "chunk_ok", time: "...", chapter: "dc_ardcollections", chunk: 1, lines: "11-23", label: "chunk_1", eval: true, elapsed: 0.5, images: 0}
- {event: "chunk_skip", time: "...", chapter: "dc_ardcollections", chunk: 2, lines: "30-45", label: "chunk_2", elapsed: 12.3}
- {event: "chapter_end", time: "...", chapter: "dc_ardcollections", elapsed: 147.4, avg: 147.4, remaining: 4, eta: "2026-08-08T01:35:00"}
- {event: "run_end", time: "...", elapsed: 3600.0, errors: 0}
```

Parseable in one shot via `yaml::read_yaml()`.

### Test suite

The package includes unit and integration tests under
`tests/testthat/`:

- **test-extract_r_chunks.R** -- chunk extraction, label precedence,
  eval detection, Python chunk exclusion.
- **test-build_data_script.R** -- generated wrapper script contents,
  chapter selection/exclusion.
- **test-generate_book_data.R** -- end-to-end: registry skip logic,
  error recording, hash-change re-runs, chapter isolation,
  eval:true always-run behavior.
- **test-snapshot.R** -- snapshot/restore unit tests: variable
  isolation, size guard, hash invalidation, eval:true exclusion.
- **test-snapshot_diagnostics.R** -- `snapshot_info()`/
  `write_snapshot_summary()`: status classification, size/variable
  counts, CSV export.
- **test-integration_dc_merge.R** -- synthetic integration test
  reproducing the `dc_merge.qmd` bridge shape (chained `eval: false`
  chunks) across repeated `generate_book_data()` runs.
- **test-registry.R** -- hash stability, round-trip, `registry_clear`.
- **test-registry_reports.R** -- all report functions, legacy tolerance,
  CSV export, event-log parsing.
- **test-log_event.R** -- YAML escaping, parseable log format.
- **test-plot_capture.R** -- base-graphics capture, deferred-render
  handling.

### CI

`.github/workflows/R-CMD-check.yaml` runs `R CMD check` on five
OS/R-version combinations:

- macOS-latest / R release
- Windows-latest / R release
- Ubuntu-latest / R devel, release, oldrel-1

### Known limitations

**No Python-side snapshotting.** The snapshot/restore mechanism
(section 7) is R-only. `pysits` objects wrap live R pointers via
`rpy2`/`reticulate` rather than plain Python data, so there is no
`pysits`-side equivalent of `saveRDS()`/`readRDS()` -- an R-side `sits`
cube or model object cannot be serialized independently of the R
session and later deserialized into a standalone Python object.

This is not a gap in practice for the current book: Python tabs get
their data via the standard bridge pattern (`read_rds("./etc/x.rds")`,
section 3.1), which works identically in Python and R since it reads a
plain, portable `.rds` file written by R -- no live R session or
`pysits` involvement is required at read time. This path is completely
independent of, and unaffected by, the R-side snapshot/restore
mechanism.

If a future chapter needs to snapshot a *plain-data* object (e.g. a
`pandas`-loadable table with no R pointers, as opposed to a `sits` cube
or model) specifically for `generate_book_data()`'s own re-run
robustness on the Python side, a portable format such as `.parquet`
(via `arrow`/`pyarrow`, readable from both R and Python) would be a
more suitable choice than `.rds`. This is not currently implemented --
`generate_book_data()` only extracts and executes R chunks (section
3.4), so there is no Python-side execution path for it to apply to yet.
