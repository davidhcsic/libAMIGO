% AMIGO_path: Detects the path of the current version of AMIGO
%
% Self-sufficient variant: resolves to the basic_amigo folder itself (the
% parent of core/), so no external AMIGO2_R2025 installation is required.

this_file = which('AMIGO_path');
if isempty(this_file)
    error('AMIGO_path: could not locate AMIGO_path.m in the MATLAB path.');
end

amigodir = fileparts(fileparts(this_file));   % core/ -> basic_amigo/

inputs.pathd.AMIGO_path = [amigodir filesep];
