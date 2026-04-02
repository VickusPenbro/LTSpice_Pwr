# LTspice MCP Proposal

## Purpose

Provide stable local tools so Codex can run LTspice workflows with less prompting while keeping all writes under:

- `G:\My Drive\BosSys\996_LTSpice\Pwr\CODEX`

## Rules

| Rule | Requirement |
|---|---|
| Read scope | `G:\My Drive\BosSys\996_LTSpice\Pwr` |
| Write scope | `G:\My Drive\BosSys\996_LTSpice\Pwr\CODEX` only |
| Network | Disabled by default |
| Privacy | Local-only, no data export |
| Execution | Prefer LTspice batch mode |

## Suggested MCP Resources

| Resource | URI example | Purpose |
|---|---|---|
| Project index | `project://index` | Discover schematics, netlists, subs, symbols |
| CODEX work index | `codex://work` | Discover copied working files |
| Latest results | `codex://results/latest` | Fast access to latest run artifacts |
| Limits/specs | `project://specs` | Pass/fail thresholds if you define them |
| Simulation history | `codex://history` | Compare previous runs |

## Suggested MCP Tools

| Tool | Purpose | Writes only in `CODEX` |
|---|---|---|
| `copy_project_file` | Copy source files into a job workspace | Yes |
| `run_ltspice_sim` | Run `.asc` or `.net` in batch mode | Yes |
| `parse_ltspice_log` | Extract measurements, warnings, errors | Yes |
| `compare_measurements` | Compare two parsed result files | Yes |
| `list_job_artifacts` | Enumerate outputs for a job | Yes |
| `render_waveform_plot` | Generate PNG/CSV from exported traces | Yes |

## Tool Definitions

### `copy_project_file`

**Input**

```json
{
  "source_path": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\New folder\\SVM.asc",
  "job_name": "svm-baseline",
  "overwrite": false
}
```

**Output**

```json
{
  "source_path": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\New folder\\SVM.asc",
  "copied_path": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\work\\svm-baseline\\SVM.asc",
  "status": "copied"
}
```

### `run_ltspice_sim`

**Input**

```json
{
  "input_path": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\work\\svm-baseline\\SVM.asc",
  "job_name": "svm-baseline",
  "ltspice_exe": "C:\\Program Files\\ADI\\LTspice\\LTspice.exe",
  "mode": "batch_ascii"
}
```

**Output**

```json
{
  "job_name": "svm-baseline",
  "status": "ok",
  "command": "\"C:\\Program Files\\ADI\\LTspice\\LTspice.exe\" -b -ascii \"...\\SVM.asc\"",
  "work_dir": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\work\\svm-baseline",
  "artifacts": {
    "log": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-baseline\\SVM.log",
    "raw": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-baseline\\SVM.raw"
  }
}
```

### `parse_ltspice_log`

**Input**

```json
{
  "log_path": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-baseline\\SVM.log",
  "job_name": "svm-baseline"
}
```

**Output**

```json
{
  "job_name": "svm-baseline",
  "status": "ok",
  "measurements": {
    "efficiency": 0.941,
    "vripple_pp": 0.82
  },
  "warnings": [],
  "errors": [],
  "json_path": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-baseline\\SVM.measurements.json"
}
```

### `compare_measurements`

**Input**

```json
{
  "baseline_json": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-baseline\\SVM.measurements.json",
  "candidate_json": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-tuned\\SVM.measurements.json",
  "job_name": "svm-compare"
}
```

**Output**

```json
{
  "job_name": "svm-compare",
  "status": "ok",
  "comparison_json": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-compare\\comparison.json",
  "comparison_csv": "G:\\My Drive\\BosSys\\996_LTSpice\\Pwr\\CODEX\\results\\svm-compare\\comparison.csv"
}
```

## Guard Conditions

| Check | Action |
|---|---|
| Source outside project root | Reject |
| Write outside `CODEX` | Reject |
| Missing LTspice exe | Return actionable error |
| Missing dependent model file | Return list of missing files |
| GUI-only operation requested | Prefer batch or reject |

## Suggested Implementation Notes

| Item | Recommendation |
|---|---|
| Language | PowerShell or Python |
| Process launch | `Start-Process` or direct invocation |
| Path validation | Resolve absolute path before action |
| Results | JSON first, CSV optional |
| Plots | Save PNG into `CODEX\results\<job>` |

## Minimal First Version

Implement only:

1. `copy_project_file`
2. `run_ltspice_sim`
3. `parse_ltspice_log`
4. `compare_measurements`

That is enough for a practical autonomous LTspice loop.
