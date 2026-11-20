% mini_run_example.m — self-contained demo of the minimal costMex workflow.
%
%   Step 1: build a tiny 2-experiment charmodelC problem in memory
%   Step 2: inputs = mini_AMIGO_prep(inputs)     (generates + mexes costMex)
%   Step 3: mini_AMIGO_sim(inputs, privstruct)   (runs sim_CVODES)
%
% Requires a working MEX C compiler (mex -setup) and, on macOS:
%   brew install libomp
% The libAMIGO static libraries are built automatically on first run.

%% Paths -------------------------------------------------------------------
this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, 'core'));
addpath(fullfile(this_dir, 'libAMIGO'));

%% Problem ------------------------------------------------------------------
% Simple 1-state model with 1 genetic stimulus S0 and 2 observables.
inputs.pathd.results_folder = 'mini_amigo';
inputs.pathd.short_name     = 'mini_demo';

inputs.model.input_model_type = 'charmodelC';
inputs.model.exe_type         = 'costMex';

inputs.model.n_st     = 1;
inputs.model.st_names = 'X';
inputs.model.eqns     = 'dX=k1*S0*X-k2*X';

inputs.model.n_par      = 2;
inputs.model.par_names  = char({'k1'; 'k2'});
inputs.model.par        = [0.1; 0.02];

inputs.model.n_stimulus     = 1;
inputs.model.stimulus_names = 'S0';

inputs.ivpsol.rtol = 1e-5;
inputs.ivpsol.atol = 1e-6;
inputs.ivpsol.max_step_size  = 100;
inputs.ivpsol.ivp_maxnumsteps = 10000;
inputs.ivpsol.nthreads = 4;

inputs.exps.data_type  = 'real';
inputs.exps.noise_type = 'homo_var';
inputs.PEsol.PEcost_type = 'lsq';

% Nothing estimated here: simulation only. Bounds around the nominal values
% keep the MEX happy (it always reads LB/UB/guess for the optimized set).
inputs.PEsol.id_global_theta  = char({'k1'; 'k2'});
inputs.PEsol.global_theta_min = [0.001; 0.0001]';
inputs.PEsol.global_theta_max = [10;    10]';

n_exp = 2;
for iexp = 1:n_exp
    t = linspace(0, 60, 40);

    inputs.exps.n_exp = n_exp;

    inputs.exps.obs{iexp}      = char({'Xobs=X', 'X2obs=2*X'});
    inputs.exps.obs_names{iexp} = char({'Xobs'; 'X2obs'});
    inputs.exps.n_obs{iexp}    = 2;

    inputs.exps.exp_data{iexp}  = zeros(numel(t), 2);   % placeholder
    inputs.exps.error_data{iexp}= ones(numel(t), 2);

    inputs.exps.t_s{iexp} = t;
    inputs.exps.n_s{iexp} = numel(t);
    inputs.exps.t_f{iexp} = t(end);
    inputs.exps.t_in{iexp} = 0;
    inputs.exps.exp_y0{iexp} = 1;

    % Constant stimulus (different per experiment).
    % NOTE: t_con must have exactly n_steps+1 entries (one value of u per
    % interval). Keep control times strictly between sampling times: in the
    % costMex C loop, control times coinciding with sampling times make the
    % stimulus index (stop_ti-2) go negative and read garbage.
    inputs.exps.u_interp{iexp} = 'step';
    inputs.exps.t_con{iexp}    = [0, t(2:end-1)-0.5*mean(diff(t)), t(end)];
    inputs.exps.n_steps{iexp}  = numel(t) - 1;
    inputs.exps.u{iexp}        = repmat(0.5 + 0.5*iexp, 1, numel(t)-1);
end

%% Step 2: prepare (generate C code + compile costMex) -----------------------
clear mex;   % avoid stale compiled models
[inputs, privstruct] = mini_AMIGO_prep(inputs);

%% Step 3: simulate ----------------------------------------------------------
results = mini_AMIGO_sim(inputs, privstruct);

%% Numeric check against a plain MATLAB reference -----------------------------
k1 = inputs.model.par(1); k2 = inputs.model.par(2);
max_err = 0;
for iexp = 1:inputs.exps.n_exp
    S0 = inputs.exps.u{iexp}(1,1);
    kEff = k1*S0 - k2;
    t_ref = results.sim.tsim{iexp}(:);
    X_ref = exp(kEff*t_ref);                  % analytic solution, X0=1
    err = max(abs(results.sim.obs{iexp}(:,1) - X_ref) ./ max(1, abs(X_ref)));
    fprintf('  exp %d: max relative error vs analytic = %.3e\n', iexp, err);
    max_err = max(max_err, err);
end
assert(all([results.sim.success{:}]),  'Integration reported failure.');
assert(all(isfinite(results.sim.obs{1}(:))), 'Non-finite observables.');
assert(max_err < 1e-2, 'costMex disagrees with ode15s reference (err=%g).', max_err);
fprintf('Numeric check OK: max relative error = %.3e\n', max_err);

%% Plot ----------------------------------------------------------------------
figure('Color', 'w');
for iexp = 1:inputs.exps.n_exp
    subplot(1, n_exp, iexp);
    plot(results.sim.tsim{iexp}, results.sim.obs{iexp}, 'LineWidth', 1.5);
    grid on;
    title(sprintf('Experiment %d (S0 = %.1f)', iexp, inputs.exps.u{iexp}(1,1)));
    legend(cellstr(inputs.exps.obs_names{iexp}), 'Location', 'best');
    xlabel('Time');
end
sgtitle('mini\_AMIGO costMex simulation');

fprintf('\nDone. Generated files in: %s\n', inputs.pathd.problem_folder_path);
