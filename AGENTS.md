# AGENTS.md — basic_amigo

## What this project is

Self-sufficient minimal AMIGO costMex runner (MATLAB) plus the MEIGO
sequential warm-start pipeline (`MEIGO_sequential_warmstart_qwen/`) that
uses it. No external AMIGO2_R2025 installation is required — see
`README.md` for the full layout and library-compilation details.

## Agent working rules

- **Never loop on the same command.** If a search/grep/command returns
  nothing useful or repeats, stop immediately, state what you know, and
  change approach (different tool, different file, or ask the user).
  Repeating an action that isn't producing information is a bug in the
  workflow, not a strategy.
- If you notice you are repeating yourself, say so explicitly (e.g.
  "I looped again on the same grep — my mistake, stopping that") and
  break the loop on the spot.
- Prefer reading a file directly over re-grepping it repeatedly.
- Long MATLAB batch runs: `export TMPDIR=/tmp` first (headless startup
  hangs otherwise).

## Key files

| File | Role |
|---|---|
| `mini_AMIGO_prep.m` | Replaces `AMIGO_Prep` for `costMex` + `charmodelC` |
| `mini_AMIGO_sim.m` | Replaces `AMIGO_SData` (calls `sim_CVODES`) |
| `mini_AMIGO_buildlibs.m` | Builds `libAMIGO.a`, `libmxInterface.a`, `libf2c.a` (from source) |
| `mini_run_example.m` | Self-contained demo with numeric check |
| `core/` | Trimmed MATLAB core (defaults, checks, C generation) |
| `libAMIGO/` | C sources + Makefile + `mexAMIGOinterface.m` |
| `MEIGO_sequential_warmstart_qwen/AGENTS.md` | Rules/notes specific to the MEIGO pipeline |

## Conventions

- Generated problem files go to `Results/<inputs.pathd.results_folder>/`.
- `clear mex` before `mini_AMIGO_prep` to avoid stale compiled models.
- See `README.md` for costMex gotchas (index_observables, t_con, theta
  handling, global_theta_guess sync, 150-experiment padding).
