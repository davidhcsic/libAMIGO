function mini_AMIGO_buildlibs(force)
% mini_AMIGO_buildlibs: Build the static libraries needed by costMex.
%
%   mini_AMIGO_buildlibs()        - build only if missing
%   mini_AMIGO_buildlibs(true)    - force a clean rebuild
%
% Builds (inside libAMIGO/lib_mac64/):
%   libAMIGO.a        simulation kernel (CVODES + NL2SOL + DE + SRES)
%   libmxInterface.a  MATLAB/MEX interface layer
%   libf2c.a          f2c runtime (built from the bundled Netlib sources)
%
% Requires: make, a C compiler, and (macOS) brew install libomp.

if nargin < 1, force = false; end

this_dir = fileparts(mfilename('fullpath'));
lib_dir  = fullfile(this_dir, 'libAMIGO');
out_dir  = fullfile(lib_dir, 'lib_mac64');

libs = {'libAMIGO.a', 'libmxInterface.a', 'libf2c.a'};
need = force | ~all(cellfun(@(f) isfile(fullfile(out_dir, f)), libs));

if ~need
    fprintf('------> Static libraries already present in %s\n', out_dir);
    return
end

[status, results] = system('which make');
if status ~= 0
    error('mini_AMIGO_buildlibs: ''make'' not found. Install Xcode command line tools.');
end

if ispc()
    error('mini_AMIGO_buildlibs: automatic library build is only supported on Unix/macOS.');
end

matlab_arch = computer('arch');
matlab_path = matlabroot;
matlab_lib  = fullfile(matlab_path, 'bin', matlab_arch);

if strcmp(matlab_arch, 'maca64') || strcmp(matlab_arch, 'maci64')
    libomp_prefix = '/opt/homebrew/opt/libomp';
    if ~isfile(fullfile(libomp_prefix, 'include', 'omp.h'))
        error('mini_AMIGO_buildlibs: OpenMP not found under %s. Run: brew install libomp', libomp_prefix);
    end
end

if force
    fprintf('------> Cleaning previous library build ...\n');
    [status, msg] = system(sprintf('cd %s && make clean', ...
        sprintf('"%s"', lib_dir)));
    if status ~= 0, error('make clean failed:\n%s', msg); end
end

fprintf('------> Building libAMIGO static libraries (this may take a few minutes) ...\n');
cmd = sprintf('cd "%s" && make all MATLAB_PATH="%s" MATLAB_LIB="%s" -j4', ...
    lib_dir, matlab_path, matlab_lib);
[status, msg] = system(cmd);
if status ~= 0
    error('mini_AMIGO_buildlibs: library build failed:\n%s', msg);
end

fprintf('------> Libraries built in %s\n', out_dir);
end
