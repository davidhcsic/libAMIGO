# basic_amigo — self-sufficient minimal AMIGO costMex runner

Minimal replacement for `AMIGO_Prep` + simulation, specialized for
`inputs.model.exe_type = 'costMex'` with `charmodelC` models.

**This folder is fully self-sufficient.** It contains the trimmed MATLAB
core, the complete libAMIGO C sources (CVODES, NL2SOL, DE, SRES, f2c
runtime), the Makefile, and the MEX interface. No external AMIGO2_R2025
installation is required — you can move or copy this folder anywhere.

## Layout

| Path | Role |
|---|---|
| `mini_AMIGO_prep.m` | `[inputs, privstruct] = mini_AMIGO_prep(inputs)` — builds static libs (if needed), checks inputs, generates `amigoRHS.c`, compiles the OpenMP `costMex` MEX, builds `privstruct`. |
| `mini_AMIGO_sim.m` | `[results, inputs] = mini_AMIGO_sim(inputs, privstruct, theta)` — calls `sim_CVODES`. `theta` optional (defaults to `inputs.model.par` at `PEsol.index_global_theta`). |
| `mini_AMIGO_buildlibs.m` | Builds the static libraries (called automatically by prep; run manually with `mini_AMIGO_buildlibs(true)` to force a rebuild). |
| `mini_run_example.m` | Self-contained 2-experiment demo with a numeric check against the analytic solution. |
| `core/` | Trimmed MATLAB code: defaults, input checking, C code generation, theta handling, solver option defaults. |
| `libAMIGO/` | C sources + `Makefile` for the simulation kernel, plus `mexAMIGOinterface.m` (MEX linker wrapper). |
| `libAMIGO/lib_mac64/` | Built static libraries: `libAMIGO.a`, `libmxInterface.a`, `libf2c.a`. |
| `Results/<results_folder>/` | Generated `amigoRHS.c` and `costMex_*.mexmaca64` per problem. |

## Usage

```matlab
addpath('core'); addpath('libAMIGO');   % or just run mini_run_example
clear mex;                              % avoid stale compiled models
[inputs, privstruct] = mini_AMIGO_prep(inputs);
results = mini_AMIGO_sim(inputs, privstruct);
```

## Library compilation (what happens on first run)

`mini_AMIGO_prep` calls `mini_AMIGO_buildlibs`, which runs
`make -C libAMIGO all`. This compiles, from source, in
`libAMIGO/lib_mac64/`:

1. **`libAMIGO.a`** — simulation/optimization kernel:
   `src_amigo` (model + CVODES driver), `src_cvodes` (CVODES ODE/SA solver),
   `src_nl2sol` (NL2SOL port, f2c-translated), `src_de` (differential
   evolution), `src_SRES`.
2. **`libmxInterface.a`** — the MATLAB/MEX entry layer
   (`src_mxInterface/AMIGO_mxInterface.c`, `lib_AMIGO_entry.c`).
3. **`libf2c.a`** — the f2c Fortran-to-C runtime, built from the bundled
   Netlib sources in `libAMIGO/f2c/libf2c_src` (via its own `makefile.u`).

The `costMex` MEX itself is then linked against these three archives plus
MATLAB's `mwblas`/`mwlapack` and the OpenMP runtime.

To rebuild everything from scratch:

```matlab
mini_AMIGO_buildlibs(true)
```

or from a shell:

```sh
cd libAMIGO && make clean && make all MATLAB_PATH=/Applications/MATLAB_R2026a.app MATLAB_LIB=$MATLAB_PATH/bin/maca64 -j4
```

## Requirements

- MATLAB with a working MEX C compiler (`mex -setup`).
- `make` + a C compiler (Xcode command line tools on macOS).
- macOS: `brew install libomp` (the kernel and MEX link against
  `/opt/homebrew/opt/libomp`).
- Headless runs: use `export TMPDIR=/tmp` before `matlab -batch` (the
  sandboxed default TMPDIR makes MATLAB hang on startup).

## Gotchas found while building this (costMex quirks)

1. **Observables via equations need `index_observables{iexp} = []`.**
   The MEX checks `privstruct.index_observables{iexp}`: an empty cell
   `{[]}` means "call the generated `amigoRHS_get_OBS` function"; a cell of
   state indices means "extract those states directly". `AMIGO_check_obs`
   never sets the empty cell, so `mini_AMIGO_prep` forces it. Otherwise
   observables are silently taken as states 1..n_obs.
2. **`t_con` must have exactly `n_steps+1` entries** (one u value per
   interval), and control times should NOT coincide with sampling times:
   in `simulate_amigo_model.c` the stimulus index `stop_ti-2` can go
   negative and read garbage memory (symptom: wrong trajectory, no error).
3. **`privstruct.theta` must be built manually** — `AMIGO_init_theta`
   leaves `theta` in the base workspace, invisible inside functions.
4. The MEX re-reads `inputs.PEsol.global_theta_guess` for the optimized
   entries at every call; `mini_AMIGO_sim` keeps it in sync with `theta`.
5. `AMIGO_check_model` pads cell fields back to the 150-experiment
   defaults, so per-experiment fixes must be applied AFTER it runs.
