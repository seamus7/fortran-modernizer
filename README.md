# fortran-modernizer

Two things in one repo:

1. **Fortran source files** that the homelab-v2 modernizer service indexes and translates. The `samples/` directory contains synthetic geodesy code designed to exercise realistic legacy patterns (COMMON blocks, GOTO, implicit typing, fixed-format F77). The root-level files (`hello.f90`, `array_ops.f90`, `io_handler.f`) are the original benchmarking fixtures.

2. **CI analysis pipeline** (`analyze.py` + `.gitea/workflows/analyze.yml`) that fires on every push of Fortran files, sends each file to two local LLMs for security and code-quality analysis, and logs results to MLflow. This is Phase C of the homelab project — automated LLM analysis of legacy code as a portfolio demonstration.

---

## CI Analysis Pipeline

### Trigger

`.gitea/workflows/analyze.yml` fires on push of any `**.f90`, `**.f`, or `**.for` file.

### What `analyze.py` does

1. Discovers all Fortran files in the repo (`**/*.f90`, `**/*.f`, `**/*.for`).
2. For each model in `["gemma3:27b", "qwen3-coder-next"]`, runs every file through the Ollama `/api/generate` endpoint with the prompt:
   > *Analyze this legacy Fortran for security vulnerabilities and suggest a Python equivalent.*
3. Logs an MLflow run per file per model under the `Fortran_Modernization` experiment.
4. After all files for a given model are processed, waits 5 seconds and calls `unload_model()` (sets `keep_alive: 0` via the Ollama API) before loading the next model.

**Loop order — models outer, files inner.** This is intentional: loading a 27B model and immediately offloading it before the next model loads avoids simultaneous VRAM residency.

### Metrics logged per run

| Metric | Description |
|---|---|
| `inference_time_sec` | Wall-clock time for the Ollama request |
| `lines_of_code` | Non-empty, non-comment source lines |
| `vulnerability_count` | Occurrences of keywords: `vulnerability`, `risk`, `overflow`, `unsafe`, `deprecated` in the LLM response |
| `has_goto` | 1 if source contains a `GOTO` statement |
| `has_common_block` | 1 if source contains a `COMMON` block |
| `has_implicit` | 1 if source contains an `IMPLICIT` statement |
| `token_count` | `total_duration` from the Ollama response (nanoseconds) |

Params logged: `model`, `file`, `hardware` (`RTX 5090`). Each run also uploads a `report.txt` artifact containing the full LLM response.

### Model comparison findings

Benchmarked on the original 4-file set (8 runs per push, 4 files × 2 models):

- **gemma3:27b** — ~19s per file. Catches broad categories but responses tend to stay surface-level.
- **qwen3-coder-next** — ~111s per file. Slower but identifies specific patterns gemma misses: atomic write hazards, file descriptor leaks, and race conditions.

---

## Sample Files

### `samples/coord_transform.f90`

WGS84 geodetic coordinate transforms. Six subroutines:

| Subroutine | Purpose |
|---|---|
| `INIT_WGS84` | Loads ellipsoid constants into `COMMON /WGS84/` |
| `GEO2ECEF` | Geodetic (lat, lon, height) → ECEF Cartesian |
| `ECEF2GEO` | ECEF → geodetic, iterative Bowring method |
| `ROT_ENU` | Builds 3×3 ECEF-delta → ENU rotation matrix |
| `ECEF2ENU` | ECEF point → ENU relative to a reference point |
| `BASELINE` | ENU baseline vector between two geodetic points |

Legacy patterns: `COMMON /WGS84/` shared across subroutines; `GOTO`-based loop control in `ECEF2GEO` (iteration divergence exit at label 99, convergence loop via label 10); terse variable names (`phi0`, `phi1`, `dphi`, `Nphi`). The math is real: Bowring iteration converges to geodetic latitude from ECEF in under 5 iterations for any point on Earth's surface.

### `samples/gravity_model.f`

Fixed-format Fortran 77. Normal gravity, terrain corrections, and station interpolation. Four subroutines:

| Subroutine | Purpose |
|---|---|
| `GRVNRM` | Normal gravity via Somigliana formula (GRS80 ellipsoid) |
| `GRVINT` | Inverse-distance weighted gravity estimate from 3 stations |
| `BOUGUER` | Complete Bouguer correction (free-air + Bouguer plate) |
| `GRVFAC` | Bouguer anomaly from observed gravity; calls `GRVNRM` and `BOUGUER` |

Legacy patterns: `IMPLICIT REAL*8 (A-H, O-Z)` and `IMPLICIT INTEGER (I-N)` (no `IMPLICIT NONE`); implicit typing used throughout `GRVINT` (plain `REAL` declarations, no kind specifier); C-style comment lines. `GRVFAC` aggregates calls to both `GRVNRM` and `BOUGUER` making it a natural cross-call target for the analysis pipeline.

### `samples/io_utils.f90`

Observation file I/O for a gravity reduction pipeline. Three subroutines:

| Subroutine | Purpose |
|---|---|
| `READ_OBS` | Reads ASCII observation file (lat, lon, height, g_obs per line) |
| `WRITE_RESULTS` | Writes reduced anomalies and computes mean/RMS statistics |
| `FORMAT_LINE` | Formats a single data line for output |

Legacy patterns: `GOTO`-based read loop in `READ_OBS` (label 20 / label 60); hardcoded `MAXPTS = 500` with array overflow guard; `WRITE_RESULTS` intentionally violates SRP — it both writes the output file and computes field statistics (the source comment acknowledges this: `! TODO: the statistics part should really be a separate routine`); dead code branch in `WRITE_RESULTS` (`IF (npts .LT. 0)`) that can never be reached given how `READ_OBS` calls it.

### `samples/math_utils.f90`

`FACTORIAL` and `POWER` functions wrapped in a `MODULE MATH_UTILS`. Both functions cap at `3.4E38` (single-precision max) to prevent overflow rather than raising an error. `FACTORIAL` returns `-1.0` for negative input. Demonstrates the Fortran 90 `MODULE` / `CONTAINS` pattern as a contrast to the free-standing subroutines in the other samples.

### `hello.f90`

Bare `PROGRAM hello` — sums integers 1–10. Original pipeline test fixture used to validate DinD (Docker-in-Docker) and model pull during CI setup.

### `samples/array_ops.f90`

Fixed-format Fortran 77 program. Fills two 100-element arrays and combines them. Patterns: `IMPLICIT INTEGER (A-Z)` applied globally; two `COMMON` blocks (`/DATA/` and `/SCALARS/`); labelled `DO` loops (`DO 10`, `DO 20`).

### `samples/io_handler.f`

Fixed-format Fortran 77 program. Opens two files, reads a value, branches on range. Heavy `GOTO` usage for control flow: range checks branch to labels 100 and 200, all paths converge at 300, error handlers at 997/998/999. No `IMPLICIT NONE`. Demonstrates the label-spaghetti pattern the modernizer is built to untangle.

---

## Connection to the Modernizer Service

The modernizer service (homelab-v2) interacts with this repo in two ways:

**Indexing.** The service mounts this repo read-only at `/data/fortran` inside the pod. Sending `POST /index` with that path causes the service to walk the directory, parse each Fortran file, and store its structure in the vector index.

**Translation PRs.** When the service produces a modernized Python translation, it opens a pull request back into this repo targeting the `modernized/` branch.

**CI pipeline.** The Gitea Actions workflow in `.gitea/workflows/analyze.yml` runs `analyze.py` on every push that touches Fortran files, hitting the in-cluster Ollama and MLflow endpoints.

---

## Running the Pipeline Locally

```bash
pip install mlflow requests

export MLFLOW_URI=http://<your-mlflow-host>:5000
export OLLAMA_URI=http://<your-ollama-host>:11434/api/generate

python analyze.py
```

Both environment variables are required — the script will raise `KeyError` at startup if either is missing.

Results appear in the MLflow UI under the `Fortran_Modernization` experiment. Each run is named `analyze_<filename>_<model>` and includes the full LLM response as a `report.txt` artifact.

---

## Repo Structure

```
.
├── analyze.py                  # CI analysis script
├── hello.f90                   # Original pipeline test fixture
├── .gitea/
│   └── workflows/
│       └── analyze.yml         # Gitea Actions workflow
└── samples/
    ├── array_ops.f90           # F77: COMMON blocks, labelled DO loops
    ├── coord_transform.f90     # F90: WGS84 transforms, COMMON, GOTO
    ├── gravity_model.f         # F77: implicit typing, Somigliana/Bouguer
    ├── io_handler.f            # F77: GOTO-heavy file I/O
    ├── io_utils.f90            # F90: GOTO read loop, SRP violation, dead code
    └── math_utils.f90          # F90: MODULE wrapper, overflow protection
```
