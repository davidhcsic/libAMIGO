function [inputs, privstruct] = mini_AMIGO_prep(inputs)
% mini_AMIGO_prep: Minimal preparation of a costMex (C model) session.
%
%   [inputs, privstruct] = mini_AMIGO_prep(inputs)
%
% Replaces AMIGO_Prep for the ONLY purpose of building and mexing the
% costMex shared-algebraics model of a charmodelC problem, and returning
% the privstruct needed by mini_AMIGO_sim.
%
% Self-sufficient: everything (MATLAB core code, libAMIGO C sources,
% Makefile) lives inside this folder. No external AMIGO2_R2025 needed.
%
% Required inputs fields (besides the standard AMIGO model/exps fields):
%   inputs.pathd.results_folder   folder under Results for generated files
%   inputs.pathd.short_name       name tag for the generated mex/obs files
%   inputs.model.exe_type         must be 'costMex'
%   inputs.model.input_model_type must be 'charmodelC'
%   inputs.exps.n_exp             actual number of experiments
%   inputs.PEsol.id_global_theta  'all' (default) or char matrix of names
%   inputs.PEsol.global_theta_min/max/guess  bounds/guess for the above
%
% See mini_run_example.m for a self-contained demo.

this_dir = fileparts(mfilename('fullpath'));
if exist('AMIGO_private_defaults', 'file') ~= 2
    addpath(fullfile(this_dir, 'core'));
    addpath(fullfile(this_dir, 'libAMIGO'));
end

if ~strcmp(inputs.model.exe_type, 'costMex')
    error('mini_AMIGO_prep: only inputs.model.exe_type = ''costMex'' is supported.');
end

%% ------------------------------------------------- build static libraries
mini_AMIGO_buildlibs();

%% ---------------------------------------------------------------- defaults
inputs_def = AMIGO_private_defaults();
inputs_def = AMIGO_public_defaults(inputs_def);

[inputs, results] = AMIGO_check_model(inputs, inputs_def);
inputs = AMIGO_check_nlp_options(inputs);
inputs = AMIGO_check_customnames(inputs);

%% ---------------------------------------------------------------- paths
% Generated files live inside this folder: Results/<results_folder>.
results.pathd.problem_folder_path = fullfile( ...
    this_dir, 'Results', results.pathd.results_folder);

if ~isdir(results.pathd.problem_folder_path)
    mkdir(results.pathd.problem_folder_path);
end
addpath(results.pathd.problem_folder_path);

inputs.pathd.problem_folder_path = results.pathd.problem_folder_path;

%% ------------------------------------------------- costMex file naming
[inputs, results] = AMIGO_check_costFullMex(inputs, results);

%% ------------------------------------------------- generate amigoRHS.c
if ~isempty(inputs.model.eqns) && inputs.model.overwrite_model
    fprintf('\n------> Generating C code (amigoRHS.c) ...\n');
    AMIGO_gen_C;
end

%% ------------------------------------------------- compile costMex MEX
if exist(inputs.model.mexfunction, 'file') == 3
    clear(inputs.model.mexfunction);
end

fprintf('\n------> Compiling costMex MEX ...\n');
mexAMIGOinterface( ...
    inputs.model.odes_file, ...
    inputs.model.mexfile, ...
    inputs.model.use_user_obs, ...
    inputs.model.use_user_sens_obs, ...
    false);

%% ------------------------------------------------- privstruct for sim
privstruct = inputs.exps;

% Build theta explicitly (AMIGO_init_theta leaves it in the base workspace,
% which is not visible from inside a function).
privstruct.theta = [inputs.PEsol.global_theta_guess, ...
    inputs.PEsol.global_theta_y0_guess, ...
    cell2mat(inputs.PEsol.local_theta_guess), ...
    cell2mat(inputs.PEsol.local_theta_y0_guess)];

% The MEX selects observables via privstruct.index_observables: a cell of
% state indices means direct state extraction; an empty cell {[]} means
% "evaluate the generated amigoRHS_get_OBS function" (use_obs_func=1).
% AMIGO_check_model trims empty default cells back to 150 entries, so the
% first n_exp cells may still be the defaults; force the empty cell here.
for iexp = 1:inputs.exps.n_exp
    if ~isempty(inputs.exps.obs{iexp}) && ~strcmp(inputs.exps.obs{iexp}, 'states')
        inputs.exps.index_observables{iexp} = [];
        privstruct.index_observables{iexp}  = [];
    end
end

for iexp = 1:inputs.exps.n_exp
    privstruct.n_s{iexp}    = inputs.exps.n_s{iexp};
    privstruct.t_int{iexp}  = inputs.exps.t_s{iexp};
    privstruct.Q{iexp}      = ones(inputs.exps.n_obs{iexp}, inputs.exps.n_s{iexp});
    privstruct.w_obs{iexp}  = ones(1, inputs.exps.n_obs{iexp});
end

% theta -> par / y_0 (uses the global_theta_guess set by AMIGO_init_theta
% inside AMIGO_check_costFullMex, so it matches inputs.model.par when the
% guess was taken from the nominal parameters).
privstruct = AMIGO_transform_theta(inputs, results, privstruct);

% The MEX simulation path initializes optimized entries from
% global_theta_guess; keep it consistent with the active parameter vector.
if inputs.PEsol.n_global_theta > 0
    inputs.PEsol.global_theta_guess = ...
        inputs.model.par(inputs.PEsol.index_global_theta);
end

inputs.exps.exp_y0 = privstruct.y_0;

fprintf('\n------> mini_AMIGO_prep done. MEX: %s\n', inputs.model.mexfunction);
end
