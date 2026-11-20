function [results, inputs] = mini_AMIGO_sim(inputs, privstruct, theta)
% mini_AMIGO_sim: Run the costMex MEX simulation (sim_CVODES).
%
%   [results, inputs] = mini_AMIGO_sim(inputs, privstruct)
%   [results, inputs] = mini_AMIGO_sim(inputs, privstruct, theta)
%
% Simulates all experiments with the OpenMP-enabled costMex model built by
% mini_AMIGO_prep. This mirrors the 'costMex' branch of
% AMIGO_smooth_simulation but without any plotting/reporting.
%
% Optional theta: row vector of global parameters (the ones indexed by
% inputs.PEsol.index_global_theta). If omitted, the values in
% inputs.model.par are used.
%
% results fields:
%   results.sim.obs        cell, n_exp x 1  observables at sampling times
%   results.sim.states     cell, n_exp x 1  states at sampling times
%   results.sim.tsim       cell, n_exp x 1  simulation time vector
%   results.sim.success    logical cell, per-experiment integration flag

if nargin < 3 || isempty(theta)
    theta = inputs.model.par(inputs.PEsol.index_global_theta);
end

if inputs.PEsol.n_global_theta > 0
    inputs.PEsol.global_theta_guess = theta(:)';
end

inputs.model.par(inputs.PEsol.index_global_theta) = theta(:)';
privstruct = AMIGO_transform_theta(inputs, [], privstruct);
inputs.exps.exp_y0 = privstruct.y_0;

feval(inputs.model.mexfunction, 'sim_CVODES');

results.sim.obs     = outputs.observables;
results.sim.states  = outputs.simulation;
results.sim.tsim    = privstruct.t_int;
results.sim.success = cellfun(@(x) logical(x), outputs.success, 'UniformOutput', false);

n_fail = sum(~[results.sim.success{:}]);
if n_fail > 0
    warning('mini_AMIGO_sim: %d of %d experiments failed to integrate.', ...
        n_fail, inputs.exps.n_exp);
end
end
