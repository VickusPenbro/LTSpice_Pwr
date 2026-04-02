# ltspice-project-operator

Use this skill for LTspice investigation, batch runs, result parsing, comparisons, and iterative design work for this project.

## Scope
- Project root: `G:\My Drive\BosSys\996_LTSpice\Pwr`
- Writable area only: `G:\My Drive\BosSys\996_LTSpice\Pwr\CODEX`
- Source files in the project root are read-only
- Copy any file to `CODEX\work` before editing or simulating if the run may generate side effects

## Goals
- Run LTspice simulations with low user interaction
- Interpret logs and measured results
- Modify copied project files inside `CODEX`
- Generate concise reports, tables, and plots

## Never Do
- Do not modify files outside `CODEX`
- Do not browse the web or use network tools unless explicitly requested
- Do not upload or share project data
- Do not delete user files unless explicitly asked

## Preferred Layout
- `CODEX\inbox`
- `CODEX\work`
- `CODEX\results`
- `CODEX\scripts`

## Workflow
1. Identify the relevant source schematic, netlist, model, and support files.
2. Copy required files into `CODEX\work\<job-name>`.
3. Run LTspice in batch mode from the copied working area.
4. Save logs and derived outputs to `CODEX\results\<job-name>`.
5. Parse `.log` files for `.meas`, warnings, and errors.
6. Summarize results using short lists and tables.
7. If asked to improve the design, edit only the copied files in `CODEX\work`.
8. Re-run and compare before/after results.

## Default Commands
- Run sim: `CODEX\scripts\run-sim.ps1`
- Parse log: `CODEX\scripts\parse-log.ps1`
- Compare runs: `CODEX\scripts\compare-measurements.ps1`

## Output Format
- Short answer
- Lists and tables
- Graph or image path when created
- Always report:
  - source file
  - copied working file
  - command used
  - pass/fail or key measurements
  - created output files

## Path Rule
Before any write:
- Resolve the path
- Confirm it starts with `G:\My Drive\BosSys\996_LTSpice\Pwr\CODEX`
- If not, stop

## Typical Prompts
- `Use the LTspice project operator skill. Copy the relevant inverter sim into CODEX, run it, and summarize the measurements.`
- `Use the LTspice project operator skill. Modify the copied compensation network in CODEX, rerun, and compare before/after.`
- `Use the LTspice project operator skill. Parse the latest log in CODEX and give me a pass/fail table.`
