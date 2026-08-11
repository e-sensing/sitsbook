# CACHING AND CHUNK MIGRATION GUIDELINES

This file explains how to migrate chapters of the book from the old
self-managed cache to knitr cached chunks. Please read it before you
change any chapter. Follow the same steps in every `.qmd` file.

The reference chapters are:

- `dc_ardcollections.qmd` — migrated up to line 758.
- `dc_merge.qmd` — migrated up to line 190, including the Python cache fix.

The chapter `dc_mixture.qmd` still uses the **old** style. Do not copy it.
Use it only to recognise what must be changed.

---

## 1. Goal of the migration

We stop managing the cache by hand. We let knitr and Quarto cache the
chunks for us. This makes chapters shorter, easier to read, and faster
to render, because expensive results are computed only once.

---

## 2. What the old style looks like (do not keep it)

In old chapters you will see two problems.

**Absolute paths.** The temporary directory is written with an absolute
or home path:

```r
tempdir_r <- "~/sitsbook/tempdir/R/dc_cubeoperations"
```

```python
tempdir_py = Path.home() / "sitsbook/tempdir/Python/dc_cubeoperations"
```

These paths are machine dependent and must not stay in the book.

**Self-managed cache (two-chunk trick).** One visible chunk shows the
real code with `#| eval: false`. A second hidden chunk with
`#| eval: true` and `#| echo: false` reloads the pre-computed result
from disk. This is the manual cache we are removing.

```r
#| eval: false
reg_cube <- sits_regularize(cube = s2_cube, output_dir = tempdir_r, ...)
```

```r
#| eval: true
#| echo: false
reg_cube <- sits_cube(source = "AWS", data_dir = tempdir_r, ...)
```

---

## 3. What the new style looks like (do this)

**Use relative paths.** The temporary directory must be relative to the
project and must match the chapter name.

```r
tempdir_r <- "./tempdir/R/dc_merge"
dir.create(tempdir_r, showWarnings = FALSE)
```

```python
tempdir_py = Path("./tempdir/Python/dc_merge")
tempdir_py.mkdir(parents=True, exist_ok=True)
```

**Give every chunk a label.** Labels are unique inside a chapter.
R chunks use a plain descriptive name. The matching Python chunk uses
the same name with a `py-` prefix.

```
#| label: merge-cube-hls        # R
#| label: py-merge-cube-hls     # Python
```

The two setup chunks are always `r-sits-load` and `py-sits-load`.

**Cache the expensive chunks.** Add `#| cache: true` to any chunk that
downloads data, builds a cube, or runs a long computation. Cheap chunks
(printing a value, a small plot from an object already in memory) do not
need it.

**Move figure settings into chunk options.** Do not set figure size or
caption inside R code. Use Quarto/knitr chunk options instead (see the
next section).

**Keep the single-chunk form.** One chunk shows the code and produces the
result. The old hidden reload chunk is deleted.

---

## 4. Chunk parameters used in the migration

Parameters are written one per line at the top of the chunk, each line
starting with `#|`.

### knitr execution parameters

| Parameter | Meaning |
|-----------|---------|
| `label` | Unique name of the chunk. Required. Use `py-` prefix for Python. |
| `cache: true` | knitr saves the chunk result and reuses it until the code changes. |
| `eval` | `true` runs the chunk, `false` shows the code without running it. |
| `echo` | `true` shows the source code, `false` hides it. |
| `output` | `false` hides all printed output (used in the setup chunks). |
| `include` | `false` runs the chunk but hides both code and output. |
| `results: hide` | Runs the chunk but hides the text results (keeps plots). |
| `warning: false` | Hides warning messages. |

### Quarto figure parameters

| Parameter | Meaning |
|-----------|---------|
| `fig-cap` | Figure caption. Use the `|` block form for multi-line text. |
| `fig-align` | Figure alignment, for example `center`. |
| `fig-width` | Figure width in inches (passed to the graphics device). |
| `fig-height` | Figure height in inches. |
| `fig-dpi` | Resolution in dots per inch, for example `300`. |
| `out-width` | Display width on the page, for example `80%`. |

A typical migrated figure chunk:

```r
#| label: fig-cube-aws-s2
#| results: hide
#| cache: true
#| fig-width: 5
#| fig-height: 5
#| fig-dpi: 300
#| fig-cap: |
#|   Sentinel-2 image of the Northeastern coast of Brazil.
#| fig-align: center
#| out-width: 80%
```

---

## 5. Special rule for Python chunks

knitr cache works differently for R and Python.

For **R**, a cached chunk saves its objects and knitr makes them
available to later chunks automatically. A later R chunk can be
uncached and still see those objects.

For **Python**, this does not happen. A cached Python chunk restores its
own variables, but a later **uncached** Python chunk does **not** see the
variables created by an earlier cached Python chunk. The variable is
simply missing and the chunk fails.

**Rule:** if a Python chunk depends on a variable created in a cached
Python chunk, that later Python chunk must also have `#| cache: true`.
In practice, cache the whole Python chain once caching starts. This is
why in `dc_merge.qmd` the Python timeline chunks carry `#| cache: true`
while their R equivalents do not.

---

## 6. The Quarto cache system

Quarto has two separate mechanisms. They work together.

### Chunk-level cache (knitr)

This is controlled by `#| cache: true` on each chunk. knitr stores the
chunk result in a `_cache` folder. The chunk runs again only when its
code changes. This is the mechanism we add during migration.

### Freeze (document level)

The project sets `freeze: auto` in `_quarto.yml`. Freeze stores the
rendered result of a whole document in the `_freeze` folder. With
`freeze: auto`, Quarto re-executes a document only when its source
changes. On a machine that does not change the file (for example the
CI/website build), the frozen result is reused and the code is not run
again.

Short summary:

- **freeze** decides whether a whole chapter is re-executed.
- **chunk cache** decides whether an individual chunk is re-executed.
- Commit the `_freeze` folder so the published site reuses results.

---

## 7. Quarto preview vs render

### `quarto preview`

`quarto preview` starts a local web server and opens the book in the
browser. It renders the file, watches it for changes, and refreshes the
page automatically when you save. Use it while you write and migrate,
because you see the effect of each change at once.

```
quarto preview dc_merge.qmd
```

It renders only what is needed and keeps running until you stop it.

### `quarto render`

`quarto render` builds the final output once and then exits. It does not
watch files and does not open a live server. Use it to produce the final
book or to check that a full build succeeds.

```
quarto render dc_merge.qmd
```

### Most useful options

| Option | Effect |
|--------|--------|
| `--to html` | Render only the HTML format. |
| `--no-cache` | Ignore the knitr chunk cache for this run. |
| `--cache-refresh` | Force all cached chunks to run again and rewrite the cache. |
| `--execute` / `--no-execute` | Force chunks to run, or skip execution. |
| `--port <n>` | (preview) Use a fixed port for the local server. |

When a cached result looks wrong or stale, render once with
`--cache-refresh` to rebuild the cache from scratch.

---

## 8. Migration checklist

For each chapter:

1. Change every temporary directory to a relative `./tempdir/...` path
   that matches the chapter name, for R and for Python.
2. Give every chunk a `label`; use the `py-` prefix for Python chunks.
3. Delete the old hidden reload chunk and keep a single chunk per step.
4. Add `#| cache: true` to expensive chunks.
5. Cache the whole downstream Python chain when a Python chunk is cached.
6. Move figure size, caption, and alignment into chunk options.
7. Run `quarto preview` and check the chapter renders correctly.
